import Foundation

@main enum MTRStationFilterChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        let planner = try MTRJourneyPlanner(csv: csv, lineIDs: ["TWL", "KTL", "ISL", "SIL", "TKL", "TCL", "AEL", "DRL", "EAL", "TML"])
        let all = MTRStationFilter.groups(stations: planner.stations, patterns: [], query: "")
        precondition(all.flatMap(\.stations).map(\.id) == planner.stations.map(\.id))
        for (line, patterns) in planner.patternsByLine {
            let groups = MTRStationFilter.groups(stations: planner.stations, patterns: patterns, query: " ")
            let ids = groups.flatMap(\.stations).map(\.id)
            precondition(ids.count == Set(ids).count)
            precondition(Set(ids) == Set(patterns.flatMap(\.stations).map(\.id)))
            if line == "TWL" {
                precondition(groups.count == 1 && ids.first == "CEN" && ids.last == "TSW")
            }
            if ["TKL", "EAL"].contains(line) { precondition(groups.contains { $0.id == "branches" }) }
        }
        let disney = MTRStationFilter.groups(stations: planner.stations, patterns: planner.patternsByLine["DRL"]!, query: "")
        precondition(disney.flatMap(\.stations).map(\.id) == ["DIS", "SUN"])
        for query in [" tsuen wan ", "荃灣", "荃湾", "tsw"] {
            let search = MTRStationFilter.groups(stations: planner.stations, patterns: planner.patternsByLine["DRL"]!, query: query)
            precondition(search.flatMap(\.stations).contains { $0.id == "TSW" })
        }
        precondition(MTRStationFilter.groups(stations: planner.stations, patterns: [], query: "nonexistent station").flatMap(\.stations).isEmpty)
        print("Station filter checks passed: all lines, route order, branch coverage, no duplicates and cross-line bilingual search.")
    }
}
