import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

struct CTBStopDetailCache: Sendable {
    static let defaultMaximumAge: TimeInterval = 30 * 86_400

    struct Position: Codable, Equatable, Sendable {
        let sequence: Int
        let stop: String
    }

    typealias Topology = [String: [Position]]

    enum Reason: String, Codable {
        case missing, expired, invalid, topologyChanged, rotation
    }

    struct Plan {
        let refresh: [String: Set<Reason>]
        let cached: [String: CTBStopRecord]
    }

    struct BootstrapResult: Codable {
        var valid = 0
        var invalid = 0
        var expired = 0
    }

    private struct Entry: Codable {
        let schemaVersion: Int
        let operatorID: String
        let stopID: String
        let sourceURL: URL
        let retrievedAt: Date
        let originalRetrievalTimestamp: String?
        let httpStatus: Int
        let sha256: String
        let validationStatus: String
        let body: Data
    }

    private struct ArchivedStop: Decodable {
        let stopId: String
        let url: URL
        let retrievedAt: String
        let status: Int
        let state: String
        let sha256: String
    }

    private struct ArchivedRoute: Decodable {
        let route: String
        let direction: String
        let url: URL
        let sha256: String
    }

    private struct RouteEnvelope: Decodable {
        let type: String
        let data: [CTBRouteStopRecord]
    }

    let directory: URL
    let maximumAge: TimeInterval

    init(directory: URL, maximumAge: TimeInterval = Self.defaultMaximumAge) {
        precondition(maximumAge.isFinite && maximumAge > 0)
        self.directory = directory
        self.maximumAge = maximumAge
    }

    func plan(stopIDs: Set<String>, topology: Topology, now: Date) -> Plan {
        let previous = (try? decode(Topology.self, from: topologyURL)) ?? [:]
        let changed = Set(previous.keys).union(topology.keys).filter { previous[$0] != topology[$0] }
        var affected = Set<String>()
        for key in changed {
            affected.formUnion((previous[key] ?? []).map(\.stop))
            affected.formUnion((topology[key] ?? []).map(\.stop))
        }

        var refresh: [String: Set<Reason>] = [:]
        var cached: [String: CTBStopRecord] = [:]
        for id in stopIDs.sorted() {
            guard let file = entryURL(id) else {
                refresh[id] = [.invalid]
                continue
            }
            guard FileManager.default.fileExists(atPath: file.path) else {
                refresh[id] = [.missing]
                continue
            }
            guard let entry = try? decode(Entry.self, from: file),
                  let record = try? validated(entry, for: id) else {
                refresh[id] = [.invalid]
                continue
            }
            let age = now.timeIntervalSince(entry.retrievedAt)
            guard age >= 0, age <= maximumAge else {
                refresh[id] = [age < 0 ? .invalid : .expired]
                continue
            }
            if affected.contains(id) { refresh[id, default: []].insert(.topologyChanged) }
            if Self.rotates(id, at: now) { refresh[id, default: []].insert(.rotation) }
            if refresh[id] == nil { cached[id] = record }
        }
        return Plan(refresh: refresh, cached: cached)
    }

    @discardableResult
    func store(_ body: Data, for id: String, sourceURL: URL, retrievedAt: Date,
               httpStatus: Int, now: Date, originalRetrievalTimestamp: String? = nil) throws -> CTBStopRecord {
        guard let file = entryURL(id), (0...maximumAge).contains(now.timeIntervalSince(retrievedAt)),
              sourceURL == CTBStopAPI.sourceURL(for: id), httpStatus == 200 else {
            throw CTBStopAPIError.invalidResponse
        }
        let record = try CTBStopAPI.decode(body, stopId: id)
        let entry = Entry(schemaVersion: 1, operatorID: "CTB", stopID: id, sourceURL: sourceURL,
                          retrievedAt: retrievedAt, originalRetrievalTimestamp: originalRetrievalTimestamp,
                          httpStatus: httpStatus, sha256: try Self.digest(body),
                          validationStatus: "valid", body: body)
        if let previous = try? decode(Entry.self, from: file), previous.retrievedAt > retrievedAt,
           (0...maximumAge).contains(now.timeIntervalSince(previous.retrievedAt)),
           let previousRecord = try? validated(previous, for: id) {
            return previousRecord
        }
        try write(entry, to: file)
        return record
    }

    func bootstrap(from directory: URL, now: Date) throws -> BootstrapResult {
        let archive = try OfflineResponseArchive(directory: directory)
        let stops = try decode([ArchivedStop].self, from: directory.appendingPathComponent("stop-detail-inventory.json"))
        let routes = try decode([ArchivedRoute].self, from: directory.appendingPathComponent("route-stop-journal.json"))
        var topology: Topology = [:]
        for route in routes {
            guard ["outbound", "inbound"].contains(route.direction),
                  !route.route.isEmpty, route.route.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }),
                  route.url.absoluteString == "https://rt.data.gov.hk/v1/transport/citybus-nwfb/route-stop/CTB/\(route.route)/\(route.direction)" else {
                throw CTBStopAPIError.invalidResponse
            }
            let (body, _) = try archive.response(for: route.url)
            let decoded = try JSONDecoder().decode(RouteEnvelope.self, from: body)
            let bound = route.direction == "outbound" ? "O" : "I"
            let positions = Self.positions(decoded.data)
            guard decoded.type == "RouteStop", try Self.digest(body) == route.sha256,
                  decoded.data.allSatisfy({ $0.companyId == "CTB" && $0.route == route.route && $0.direction == bound && CTBStopAPI.sourceURL(for: $0.stop) != nil }),
                  positions.allSatisfy({ $0.sequence > 0 }), Set(positions.map(\.sequence)).count == positions.count,
                  topology.updateValue(positions, forKey: "\(route.route)|\(route.direction)") == nil else {
                throw CTBStopAPIError.invalidResponse
            }
        }
        let ids = Set(topology.values.flatMap { $0.map(\.stop) })
        guard !ids.isEmpty, ids.count == stops.count, ids == Set(stops.map(\.stopId)) else {
            throw CTBStopAPIError.invalidResponse
        }

        var result = BootstrapResult()
        for stop in stops {
            guard stop.state == "valid", stop.status == 200, let date = Self.archiveDate(stop.retrievedAt),
                  stop.url == CTBStopAPI.sourceURL(for: stop.stopId),
                  let (body, response) = try? archive.response(for: stop.url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  try Self.digest(body) == stop.sha256,
                  (try? CTBStopAPI.decode(body, stopId: stop.stopId)) != nil else {
                result.invalid += 1
                continue
            }
            let age = now.timeIntervalSince(date)
            guard age >= 0 else {
                result.invalid += 1
                continue
            }
            guard age <= maximumAge else {
                result.expired += 1
                continue
            }
            try store(body, for: stop.stopId, sourceURL: stop.url, retrievedAt: date, httpStatus: stop.status,
                      now: now, originalRetrievalTimestamp: stop.retrievedAt)
            result.valid += 1
        }
        if !FileManager.default.fileExists(atPath: topologyURL.path) {
            try saveTopology(topology)
        }
        return result
    }

    func validateSnapshot(now: Date) throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files where file.lastPathComponent != "topology.json" {
            let entry = try decode(Entry.self, from: file)
            guard file.lastPathComponent == entryURL(entry.stopID)?.lastPathComponent, entry.retrievedAt <= now else {
                throw DatasetPreservationError.conflict("Invalid CTB cache file identity or future timestamp: \(file.lastPathComponent).")
            }
            _ = try validated(entry, for: entry.stopID)
        }
        if FileManager.default.fileExists(atPath: topologyURL.path) {
            _ = try decode(Topology.self, from: topologyURL)
        }
    }

    func refreshPlan(for archive: URL, incoming: CTBStopDetailCache, now: Date) throws -> Data {
        try validateSnapshot(now: now)
        try incoming.validateSnapshot(now: now)
        let topology = try decode(Topology.self, from: incoming.topologyURL)
        let stops = try decode([ArchivedStop].self, from: archive.appendingPathComponent("stop-detail-inventory.json"))
        let result = plan(stopIDs: Set(stops.map(\.stopId)), topology: topology, now: now)
        let report = result.refresh.mapValues { $0.map(\.rawValue).sorted() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(report)
    }

    func saveTopology(_ topology: Topology) throws {
        try write(topology, to: topologyURL)
    }

    static func positions(_ rows: [CTBRouteStopRecord]) -> [Position] {
        rows.sorted { $0.sequence < $1.sequence }.map { Position(sequence: $0.sequence, stop: $0.stop) }
    }

    private static func rotates(_ id: String, at time: Date) -> Bool {
        // Fixed ID buckets avoid moving stops between cohorts as the network changes.
        let hash = id.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        let week = Int(floor(time.timeIntervalSince1970 / (7 * 86_400)))
        return Int(hash % 4) == (week % 4 + 4) % 4
    }

    private func validated(_ entry: Entry, for id: String) throws -> CTBStopRecord {
        guard entry.schemaVersion == 1, entry.operatorID == "CTB", entry.stopID == id,
              entry.sourceURL == CTBStopAPI.sourceURL(for: id), entry.httpStatus == 200,
              entry.validationStatus == "valid", try Self.digest(entry.body) == entry.sha256 else {
            throw CTBStopAPIError.invalidResponse
        }
        if let original = entry.originalRetrievalTimestamp {
            guard let parsed = Self.archiveDate(original), abs(parsed.timeIntervalSince(entry.retrievedAt)) < 0.001 else {
                throw DatasetPreservationError.conflict("CTB cache retrieval timestamp mismatch for \(id).")
            }
        }
        return try CTBStopAPI.decode(entry.body, stopId: id)
    }

    private var topologyURL: URL { directory.appendingPathComponent("topology.json") }

    private func entryURL(_ id: String) -> URL? {
        guard CTBStopAPI.sourceURL(for: id) != nil else { return nil }
        return directory.appendingPathComponent("stop-\(id).json")
    }

    private func decode<T: Decodable>(_ type: T.Type, from file: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: file))
    }

    private func write<T: Encodable>(_ value: T, to file: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file, options: .atomic)
    }

    static func archiveDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    static func digest(_ body: Data) throws -> String {
        #if canImport(CryptoKit)
        return SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        #else
        return try OperatorShardStaging.digest(body)
        #endif
    }
}
