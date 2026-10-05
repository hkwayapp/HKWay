import Foundation

// MTR Light Rail Next Train API v1.1 / data dictionary v1.2 (2026-07-05).
// Keep operator-reported time strings: '-' and arriving/departing are not minutes.
struct LightRailETAResponse: Decodable {
    let status: Int
    let system_time: String?
    let platform_list: [LightRailETAPlatform]?

    var allRoutePlatforms: [LightRailETAPlatform] {
        guard status == 1 else { return [] }
        return (platform_list ?? []).compactMap { platform in
            let trains = (platform.route_list ?? []).filter { ($0.special ?? 0) == 0 }
            return trains.isEmpty ? nil : LightRailETAPlatform(platform_id: platform.platform_id, route_list: trains)
        }.sorted { $0.platform_id < $1.platform_id }
    }

    var timestamp: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return system_time.flatMap(formatter.date(from:))
    }

    func platforms(routeID: String, destination: LightRailStop?, circular: Bool) -> [LightRailETAPlatform] {
        guard status == 1 else { return [] }
        return (platform_list ?? []).compactMap { platform in
            let trains = (platform.route_list ?? []).filter { train in
                guard train.route_no == routeID, (train.special ?? 0) == 0 else { return false }
                if circular { return true }
                guard let destination else { return false }
                return Self.normalized(train.dest_en) == Self.normalized(destination.english)
                    || Self.normalized(train.dest_ch) == Self.normalized(destination.traditional)
            }
            return trains.isEmpty ? nil : LightRailETAPlatform(platform_id: platform.platform_id, route_list: trains)
        }.sorted { $0.platform_id < $1.platform_id }
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

struct LightRailETAPlatform: Decodable, Identifiable {
    let platform_id: Int
    let route_list: [LightRailETATrain]?
    var id: Int { platform_id }
}

struct LightRailETATrain: Decodable {
    let route_no: String
    let dest_en: String
    let dest_ch: String
    let time_en: String?
    let time_ch: String?
    let arrival_departure: String?
    let train_length: Int?
    let stop: Int?
    let special: Int?
}

struct LightRailETAService {
    func fetch(stationID: Int, session: URLSession = .shared) async throws -> LightRailETAResponse {
        guard stationID > 0,
              var components = URLComponents(string: "https://rt.data.gov.hk/v1/transport/mtr/lrt/getSchedule") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "station_id", value: String(stationID)),
            URLQueryItem(name: "with_special", value: "0")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LightRailETAResponse.self, from: data)
    }
}
