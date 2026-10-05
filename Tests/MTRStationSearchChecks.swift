import Foundation

@main enum MTRStationSearchChecks {
    static func main() throws {
        let ids = ["TWL", "KTL", "ISL", "SIL", "TKL", "TCL", "AEL", "DRL", "EAL", "TML"]
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        let entries = try MTRStationSearchIndex.parse(csv, lineIDs: ids)
        precondition(Set(entries.map(\.id)).count == entries.count)
        let adm = entries.first { $0.id == "ADM" }!
        precondition(Set(adm.patternsByLine.keys) == Set(["TWL", "ISL", "SIL", "EAL"]))
        let tsuenWan = entries.first { $0.id == "TSW" }!
        for query in ["  tsuen wan \n", "荃灣", "荃湾", "tsw", ""] {
            precondition(tsuenWan.matches(query))
        }
        precondition(!tsuenWan.matches("no-such-station"))
        let hongKong = entries.first { $0.id == "HOK" }!
        precondition(Set(hongKong.patternsByLine.keys) == Set(["TCL", "AEL"]))
        for entry in entries {
            for (line, patterns) in entry.patternsByLine {
                let initial = entry.initialPattern(lineID: line)!
                precondition(initial.stations.dropLast().contains { $0.id == entry.id })
                let expected = try MTRStations.parse(csv, line: line)
                precondition(patterns.count == expected.count)
            }
        }
        for code in ["LHP", "POA", "LMC", "LOW"] {
            precondition(entries.contains { $0.id == code })
        }
        precondition(!entries.contains { $0.id == "RAC" }) // Not in the bundled regular station catalogue.
        print("Station search checks passed for \(entries.count) unique stations: bilingual search, interchange deduplication, branches and departing directions.")
    }
}
