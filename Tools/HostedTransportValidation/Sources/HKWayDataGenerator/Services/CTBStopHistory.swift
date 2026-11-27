import Foundation

extension CTBStopRecord {
    func isValid(for stopID: String) -> Bool {
        guard stop == stopID,
              let latitude = latitudeValue, (22...23).contains(latitude),
              let longitude = longitudeValue, (113...115).contains(longitude) else { return false }
        return [nameEnglish, nameTraditional, nameSimplified].allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

struct CTBHistoricalStop: Codable, Sendable {
    let operatorID: String
    let observedAt: Date
    let stop: CTBStopRecord

    func validated(stopID: String, now: Date) -> CTBStopRecord? {
        let age = now.timeIntervalSince(observedAt)
        guard operatorID == "CTB", (0...30 * 24 * 60 * 60).contains(age),
              stop.isValid(for: stopID) else { return nil }
        return stop
    }
}

actor CTBStopHistory {
    enum Resolution: Sendable {
        case current(CTBStopRecord)
        case historical(CTBStopRecord)
    }

    private let url: URL?
    private var records: [String: CTBHistoricalStop]

    init(url: URL? = ProcessInfo.processInfo.environment["HKWAY_CTB_HISTORY"].map {
        URL(fileURLWithPath: $0)
    }, fixtures: [String: CTBHistoricalStop] = [:]) {
        let url = DatasetHTTP.replay == nil ? url : nil
        self.url = url
        var loaded = fixtures
        if let url, FileManager.default.fileExists(atPath: url.path) {
            do {
                loaded = try JSONDecoder().decode([String: CTBHistoricalStop].self, from: Data(contentsOf: url))
            } catch {
                print("CTB history ignored: \(error)")
            }
        }
        records = loaded
    }

    // Called only for exact IDs referenced by the current official route-stop feed.
    func resolve(
        _ id: String, now: Date = Date(),
        fetch: @Sendable () async throws -> CTBStopRecord
    ) async throws -> Resolution {
        do {
            let stop = try await fetch()
            guard stop.isValid(for: id) else { throw CTBStopAPIError.invalidResponse }
            records[id] = CTBHistoricalStop(operatorID: "CTB", observedAt: now, stop: stop)
            return .current(stop)
        } catch {
            try Task.checkCancellation()
            guard let entry = records[id], let stop = entry.validated(stopID: id, now: now) else {
                throw error
            }
            print("CTB stop \(id): exact historical record from \(entry.observedAt) used for staging; current fetch failed: \(error)")
            return .historical(stop)
        }
    }

    func save() {
        guard let url else { return }
        do {
            let now = Date()
            let valid = records.filter { $0.value.validated(stopID: $0.key, now: now) != nil }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(valid).write(to: url, options: .atomic)
        } catch {
            print("CTB history could not be saved: \(error)")
        }
    }
}
