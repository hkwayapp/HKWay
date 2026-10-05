import Foundation

struct MTRStationSearchEntry: Identifiable {
    let station: MTRStation
    var patternsByLine: [String: [MTRStationPattern]]
    var id: String { station.id }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || [station.english, station.traditional, station.simplified, id]
            .contains { $0.localizedStandardContains(query) }
    }

    func initialPattern(lineID: String) -> MTRStationPattern? {
        let patterns = patternsByLine[lineID] ?? []
        // Prefer a direction departing this station, especially at termini.
        return patterns.first { pattern in
            pattern.stations.dropLast().contains { $0.id == id }
        } ?? patterns.first { $0.stations.contains { $0.id == id } }
    }
}

enum MTRStationSearchIndex {
    static func load(lineIDs: [String]) throws -> [MTRStationSearchEntry] {
        guard let url = Bundle.main.url(forResource: "MTRStations", withExtension: "csv") else {
            throw MTRStations.DataError.missingFile
        }
        return try parse(String(contentsOf: url, encoding: .utf8), lineIDs: lineIDs)
    }

    static func parse(_ csv: String, lineIDs: [String]) throws -> [MTRStationSearchEntry] {
        var entries: [String: MTRStationSearchEntry] = [:]
        for lineID in lineIDs {
            let patterns = try MTRStations.parse(csv, line: lineID)
            for station in patterns.flatMap(\.stations) {
                var entry = entries[station.id] ?? MTRStationSearchEntry(station: station, patternsByLine: [:])
                // Retain every branch for the existing ETA direction controls.
                entry.patternsByLine[lineID] = patterns
                entries[station.id] = entry
            }
        }
        return entries.values.sorted { $0.station.english.localizedStandardCompare($1.station.english) == .orderedAscending }
    }
}
