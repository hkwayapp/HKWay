import Foundation

@main
struct LightRailInterchangeLinkChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        let entries = try MTRStationSearchIndex.parse(csv, lineIDs: ["TML"])
        for (id, code) in [(100, "SIH"), (295, "TUM"), (430, "TIS"), (600, "YUL")] {
            let stop = LightRailStop(stationID: id, english: "", traditional: "", simplified: "")
            precondition(stop.tuenMaStationCode == code && stop.hasTuenMaInterchange)
            let entry = entries.first { $0.id == code }!
            precondition(entry.patternsByLine["TML"]!.count == 2)
            precondition(entry.initialPattern(lineID: "TML")!.stations.dropLast().contains { $0.id == code })
        }
        let other = LightRailStop(stationID: 110, english: "", traditional: "", simplified: "")
        precondition(other.tuenMaStationCode == nil && !other.hasTuenMaInterchange)
        print("Light Rail interchange link checks passed")
    }
}
