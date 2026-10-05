import Foundation
import Observation

struct TVArrival: Identifiable, Sendable, Equatable {
    let operatorID: String
    let estimatedArrival: Date?
    let sequence: Int
    let remarkEnglish: String
    let remarkTraditional: String
    let remarkSimplified: String

    var id: String {
        "\(operatorID)|\(sequence)|\(estimatedArrival?.timeIntervalSince1970 ?? 0)"
    }

    func remark(_ language: TVLanguage) -> String {
        switch language {
        case .english: remarkEnglish
        case .traditionalChinese: remarkTraditional
        case .simplifiedChinese: remarkSimplified
        }
    }
}

enum TVETAStatus: Equatable {
    case idle
    case loading
    case available([TVArrival], updatedAt: Date)
    case noService(updatedAt: Date)
    case unavailable(updatedAt: Date?)
}

@MainActor
@Observable
final class TVETAStore {
    private(set) var statusByFavoriteID: [String: TVETAStatus] = [:]
    private let client = TVETAClient()

    var latestUpdatedAt: Date? {
        statusByFavoriteID.values.compactMap { status in
            switch status {
            case .available(_, let updatedAt), .noService(let updatedAt): updatedAt
            case .unavailable(let updatedAt): updatedAt
            case .idle, .loading: nil
            }
        }.max()
    }

    func status(for favorite: TVFavoriteBusRoute) -> TVETAStatus {
        statusByFavoriteID[favorite.id] ?? .idle
    }

    func refresh(favorites: [TVFavoriteBusRoute], data: TVBusDataStore) async {
        guard !favorites.isEmpty else {
            statusByFavoriteID = [:]
            return
        }

        let validIDs = Set(favorites.map(\.id))
        statusByFavoriteID = statusByFavoriteID.filter { validIDs.contains($0.key) }

        for favorite in favorites {
            if statusByFavoriteID[favorite.id] == nil { statusByFavoriteID[favorite.id] = .loading }
        }

        await withTaskGroup(of: (String, Result<[TVArrival], Error>).self) { group in
            for favorite in favorites {
                let references = data.operatorReferences(for: favorite)
                let favoriteID = favorite.id
                let routeNumber = favorite.number
                group.addTask { [client] in
                    do {
                        return (favoriteID, .success(try await client.fetch(
                            references: references,
                            routeNumber: routeNumber
                        )))
                    } catch {
                        return (favoriteID, .failure(error))
                    }
                }
            }

            for await (id, result) in group {
                let now = Date()
                switch result {
                case .success(let arrivals):
                    let useful = arrivals
                        .filter { arrival in
                            guard let eta = arrival.estimatedArrival else { return false }
                            return eta > now.addingTimeInterval(-60)
                        }
                        .sorted { lhs, rhs in
                            switch (lhs.estimatedArrival, rhs.estimatedArrival) {
                            case let (left?, right?): left < right
                            case (.some, .none): true
                            case (.none, .some): false
                            case (.none, .none): lhs.sequence < rhs.sequence
                            }
                        }
                    statusByFavoriteID[id] = useful.isEmpty
                        ? .noService(updatedAt: now)
                        : .available(Array(useful.prefix(3)), updatedAt: now)
                case .failure:
                    let previousUpdate: Date? = switch statusByFavoriteID[id] {
                    case .available(_, let updatedAt), .noService(let updatedAt): updatedAt
                    default: nil
                    }
                    statusByFavoriteID[id] = .unavailable(updatedAt: previousUpdate)
                }
            }
        }
    }
}

private struct TVETAClient: Sendable {
    func fetch(references: [TVOperatorStopReference], routeNumber: String) async throws -> [TVArrival] {
        guard !references.isEmpty else { throw URLError(.resourceUnavailable) }

        return try await withThrowingTaskGroup(of: [TVArrival].self) { group in
            for reference in references {
                group.addTask { try await fetch(reference: reference, routeNumber: routeNumber) }
            }

            var combined: [TVArrival] = []
            var firstError: Error?
            while !group.isEmpty {
                do { combined += try await group.next() ?? [] }
                catch { firstError = firstError ?? error }
            }
            if combined.isEmpty, let firstError { throw firstError }
            return combined
        }
    }

    private func fetch(reference: TVOperatorStopReference, routeNumber: String) async throws -> [TVArrival] {
        switch reference.operatorId {
        case "KMB", "LWB": try await fetchKMB(reference, routeNumber)
        case "CTB": try await fetchCTB(reference, routeNumber)
        case "GMB": try await fetchGMB(reference)
        case "NLB": try await fetchNLB(reference)
        case "LRTFeeder": try await fetchMTRBus(reference)
        default: throw URLError(.unsupportedURL)
        }
    }

    private func fetchKMB(_ reference: TVOperatorStopReference, _ route: String) async throws -> [TVArrival] {
        let serviceType = Int(reference.operatorServiceType) ?? 1
        let url = try makeURL("https://data.etabus.gov.hk/v1/transport/kmb/eta/\(reference.operatorStopId)/\(route)/\(serviceType)")
        let response = try await decode(KMBResponse.self, from: url)
        return response.data.filter { $0.dir == reference.operatorDirection }.map {
            TVArrival(operatorID: reference.operatorId, estimatedArrival: parseISO($0.eta), sequence: $0.etaSeq,
                      remarkEnglish: $0.rmkEN, remarkTraditional: $0.rmkTC, remarkSimplified: $0.rmkSC)
        }
    }

    private func fetchCTB(_ reference: TVOperatorStopReference, _ route: String) async throws -> [TVArrival] {
        let url = try makeURL("https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/CTB/\(reference.operatorStopId)/\(route)")
        let response = try await decode(CTBResponse.self, from: url)
        let direction = reference.operatorDirection == "outbound" ? "O" : reference.operatorDirection == "inbound" ? "I" : reference.operatorDirection
        return response.data.filter { $0.dir == direction }.map {
            TVArrival(operatorID: reference.operatorId, estimatedArrival: parseISO($0.eta), sequence: $0.etaSeq ?? 0,
                      remarkEnglish: $0.rmkEN, remarkTraditional: $0.rmkTC, remarkSimplified: $0.rmkSC)
        }
    }

    private func fetchGMB(_ reference: TVOperatorStopReference) async throws -> [TVArrival] {
        let parts = reference.operatorServiceType.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw URLError(.badURL) }
        let url = try makeURL("https://data.etagmb.gov.hk/eta/route-stop/\(parts[0])/\(reference.operatorDirection)/\(parts[1])")
        let response = try await decode(GMBResponse.self, from: url)
        guard response.data.enabled else { return [] }
        return response.data.eta.map {
            TVArrival(operatorID: reference.operatorId, estimatedArrival: parseISO($0.timestamp), sequence: $0.etaSeq,
                      remarkEnglish: $0.remarksEN, remarkTraditional: $0.remarksTC, remarkSimplified: $0.remarksSC)
        }
    }

    private func fetchNLB(_ reference: TVOperatorStopReference) async throws -> [TVArrival] {
        var components = URLComponents(string: "https://rt.data.gov.hk/v2/transport/nlb/stop.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "estimatedArrivals"),
            URLQueryItem(name: "routeId", value: reference.operatorServiceType),
            URLQueryItem(name: "stopId", value: reference.operatorStopId),
            URLQueryItem(name: "language", value: "en")
        ]
        let response = try await decode(NLBResponse.self, from: components.url!)
        return (response.estimatedArrivals ?? []).enumerated().map { index, item in
            TVArrival(operatorID: reference.operatorId, estimatedArrival: parseNLB(item.estimatedArrivalTime), sequence: index + 1,
                      remarkEnglish: item.departed == 1 && item.noGPS != 1 ? "" : "Scheduled",
                      remarkTraditional: item.departed == 1 && item.noGPS != 1 ? "" : "預定班次",
                      remarkSimplified: item.departed == 1 && item.noGPS != 1 ? "" : "预定班次")
        }
    }

    private func fetchMTRBus(_ reference: TVOperatorStopReference) async throws -> [TVArrival] {
        let url = try makeURL("https://rt.data.gov.hk/v1/transport/mtr/bus/getSchedule")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["language": "en", "routeName": reference.operatorServiceType])
        let response = try await decode(MTRResponse.self, request: request)
        guard let stop = response.busStop.first(where: { $0.busStopId == reference.operatorStopId }), stop.isSuspended != "1" else { return [] }
        let now = Date()
        return stop.bus.enumerated().compactMap { index, item in
            guard let seconds = TimeInterval(item.arrivalTimeInSecond), seconds >= 0, seconds < 86_400 else { return nil }
            return TVArrival(operatorID: reference.operatorId, estimatedArrival: now.addingTimeInterval(seconds), sequence: index + 1,
                             remarkEnglish: item.isScheduled == "1" ? "Scheduled" : "",
                             remarkTraditional: item.isScheduled == "1" ? "預定班次" : "",
                             remarkSimplified: item.isScheduled == "1" ? "预定班次" : "")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await decode(type, request: request)
    }

    private func decode<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(type, from: data)
    }

    private func makeURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else { throw URLError(.badURL) }
        return url
    }

    private func parseISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func parseNLB(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}

private struct KMBResponse: Decodable { let data: [KMBRecord] }
private struct KMBRecord: Decodable {
    let dir: String?; let etaSeq: Int; let eta: String?; let rmkTC: String; let rmkSC: String; let rmkEN: String
    enum CodingKeys: String, CodingKey { case dir, eta; case etaSeq = "eta_seq"; case rmkTC = "rmk_tc"; case rmkSC = "rmk_sc"; case rmkEN = "rmk_en" }
}
private struct CTBResponse: Decodable { let data: [CTBRecord] }
private struct CTBRecord: Decodable {
    let dir: String?; let etaSeq: Int?; let eta: String?; let rmkTC: String; let rmkSC: String; let rmkEN: String
    enum CodingKeys: String, CodingKey { case dir, eta; case etaSeq = "eta_seq"; case rmkTC = "rmk_tc"; case rmkSC = "rmk_sc"; case rmkEN = "rmk_en" }
}
private struct GMBResponse: Decodable { let data: GMBPayload }
private struct GMBPayload: Decodable { let enabled: Bool; let eta: [GMBRecord] }
private struct GMBRecord: Decodable {
    let etaSeq: Int; let timestamp: String?; let remarksTC: String; let remarksSC: String; let remarksEN: String
    enum CodingKeys: String, CodingKey { case timestamp; case etaSeq = "eta_seq"; case remarksTC = "remarks_tc"; case remarksSC = "remarks_sc"; case remarksEN = "remarks_en" }
}
private struct NLBResponse: Decodable { let estimatedArrivals: [NLBRecord]? }
private struct NLBRecord: Decodable {
    let estimatedArrivalTime: String; let departed: Int; let noGPS: Int
    enum CodingKeys: String, CodingKey { case estimatedArrivalTime, departed, noGPS }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        estimatedArrivalTime = try values.decode(String.self, forKey: .estimatedArrivalTime)
        departed = (try? values.decode(Int.self, forKey: .departed)) ?? Int((try? values.decode(String.self, forKey: .departed)) ?? "") ?? 0
        noGPS = (try? values.decode(Int.self, forKey: .noGPS)) ?? Int((try? values.decode(String.self, forKey: .noGPS)) ?? "") ?? 0
    }
}
private struct MTRResponse: Decodable { let busStop: [MTRStop] }
private struct MTRStop: Decodable { let busStopId: String; let isSuspended: String; let bus: [MTRRecord] }
private struct MTRRecord: Decodable { let arrivalTimeInSecond: String; let isScheduled: String }
