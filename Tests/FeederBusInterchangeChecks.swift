import Foundation

@main
struct FeederBusInterchangeChecks {
    static func main() throws {
        for id in ["9781", "9830", "12400", "13028", "13029", "12388", "12964",
                   "9898", "9899", "9908", "12883", "9974", "9979"] {
            precondition(FeederBusInterchange.hasTuenMaBadge(stopID: id, operatorIDs: ["LRTFeeder"]))
            precondition(!FeederBusInterchange.hasTuenMaBadge(stopID: id, operatorIDs: ["KMB"]))
            precondition(!FeederBusInterchange.hasTuenMaBadge(stopID: id, operatorIDs: []))
        }
        // Light Rail-only, police/fire stations, and unknown IDs must not match.
        for id in ["1215", "9763", "9872", "9790", "9966", "unknown", ""] {
            precondition(!FeederBusInterchange.hasTuenMaBadge(stopID: id, operatorIDs: ["LRTFeeder"]))
        }
        precondition(Set(FeederBusInterchange.tuenMaStationByStopID.values).count == 5)
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        let entries = try MTRStationSearchIndex.parse(csv, lineIDs: ["TML"])
        for code in Set(FeederBusInterchange.tuenMaStationByStopID.values) {
            let entry = entries.first { $0.id == code }!
            let pattern = entry.initialPattern(lineID: "TML")!
            precondition(pattern.stations.dropLast().contains { $0.id == code })
            precondition(entry.patternsByLine["TML"]!.count == 2)
        }
        print("Feeder bus interchange checks passed")
    }
}
