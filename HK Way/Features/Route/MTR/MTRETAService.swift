import Foundation

enum MTRTravelDirection: String, CaseIterable, Identifiable {
    case up = "UP", down = "DOWN"
    var id: String { rawValue }
    init(patternID: String) { self = patternID.hasSuffix("UT") ? .up : .down }
}

enum MTRClock {
    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        return formatter.date(from: value)
    }
}

// Documented numerical fields are also returned as strings by the live API.
private struct MTRScalar: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else { value = String(try container.decode(Int.self)) }
    }
}

struct MTRTrainPrediction: Decodable {
    let dest: String
    let time: String
    let platform: String
    let sequence: Int
    let timetype: String?
    let route: String?
    var date: Date? { MTRClock.date(time) }
    var viaRacecourse: Bool { route == "RAC" }

    private enum CodingKeys: String, CodingKey {
        case dest, time, plat, seq, timetype, route
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dest = try c.decode(String.self, forKey: .dest)
        time = try c.decode(String.self, forKey: .time)
        platform = try c.decodeIfPresent(MTRScalar.self, forKey: .plat)?.value ?? "—"
        sequence = Int(try c.decodeIfPresent(MTRScalar.self, forKey: .seq)?.value ?? "") ?? 0
        timetype = try c.decodeIfPresent(String.self, forKey: .timetype)
        route = try c.decodeIfPresent(String.self, forKey: .route)
    }
}

struct MTRStationPredictions: Decodable {
    let sys_time: String?
    let curr_time: String?
    let UP: [MTRTrainPrediction]?
    let DOWN: [MTRTrainPrediction]?

    func trains(direction: MTRTravelDirection, now: Date) -> [MTRTrainPrediction] {
        // Do not filter by branch terminus: preserve short workings and both
        // branch destinations. Dummy ttnt/valid fields are deliberately unused.
        let trains = direction == .up ? UP : DOWN
        return (trains ?? []).filter { train in
            guard let date = train.date else { return true } // Show unknown time honestly.
            return date.timeIntervalSince(now) >= -30
        }.sorted { $0.sequence < $1.sequence }
    }
}

struct MTRETAResponse: Decodable {
    let status: Int
    let message: String?
    let sys_time: String?
    let data: [String: MTRStationPredictions]?
    let isdelay: String?
    let url: String?

    private enum CodingKeys: String, CodingKey { case status, message, sys_time, data, isdelay, url }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawStatus = try c.decode(MTRScalar.self, forKey: .status).value
        guard let status = Int(rawStatus) else {
            throw DecodingError.dataCorruptedError(forKey: .status, in: c, debugDescription: "Invalid MTR status")
        }
        self.status = status
        message = try c.decodeIfPresent(String.self, forKey: .message)
        sys_time = try c.decodeIfPresent(String.self, forKey: .sys_time)
        data = try c.decodeIfPresent([String: MTRStationPredictions].self, forKey: .data)
        isdelay = try c.decodeIfPresent(String.self, forKey: .isdelay)
        url = try c.decodeIfPresent(String.self, forKey: .url)
    }

    func station(line: String, code: String) -> MTRStationPredictions? {
        guard status == 1 else { return nil }
        return data?["\(line)-\(code)"]
    }

    func updatedAt(line: String, code: String) -> Date? {
        MTRClock.date(station(line: line, code: code)?.sys_time) ?? MTRClock.date(sys_time)
    }

    var serviceNoticeURL: URL? {
        guard let url, let parsed = URL(string: url), parsed.scheme == "https",
              let host = parsed.host?.lowercased(),
              host == "mtr.com.hk" || host.hasSuffix(".mtr.com.hk") else { return nil }
        return parsed
    }
}

struct MTRETAService {
    func fetch(line: String, station: String, chinese: Bool,
               session: URLSession = .shared) async throws -> MTRETAResponse {
        var components = URLComponents(string: "https://rt.data.gov.hk/v1/transport/mtr/getSchedule.php")!
        components.queryItems = [
            URLQueryItem(name: "line", value: line),
            URLQueryItem(name: "sta", value: station),
            URLQueryItem(name: "lang", value: chinese ? "TC" : "EN")
        ]
        let request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MTRETAResponse.self, from: data)
    }
}
