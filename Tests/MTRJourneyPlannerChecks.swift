import Foundation

@main enum MTRJourneyPlannerChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        let lines = ["TWL", "KTL", "ISL", "SIL", "TKL", "TCL", "AEL", "DRL", "EAL", "TML"]
        let planner = try MTRJourneyPlanner(csv: csv, lineIDs: lines)
        let disney = planner.plan(from: "TSW", to: "DIS")!
        precondition(disney.legs.map(\.lineID) == ["TWL", "TCL", "DRL"])
        precondition(disney.legs.compactMap { $0.stations.last?.id } == ["LAK", "SUN", "DIS"])
        precondition(disney.legs.compactMap { $0.pattern.stations.last?.id } == ["CEN", "TUC", "DIS"])
        precondition(disney.changes == 2 && disney.stops == 7)
        let reverse = planner.plan(from: "DIS", to: "TSW")!
        precondition(reverse.legs.map(\.lineID) == ["DRL", "TCL", "TWL"])
        precondition(reverse.changes == 2 && reverse.stops == 7)
        let direct = planner.plan(from: "TSW", to: "CEN")!
        precondition(direct.changes == 0 && direct.legs.count == 1)
        let tklBranch = planner.plan(from: "POA", to: "LHP")!
        precondition(tklBranch.changes == 1)
        precondition(tklBranch.legs.map(\.lineID) == ["TKL", "TKL"])
        precondition(tklBranch.legs.first?.stations.last?.id == "TKO")
        let ealBranch = planner.plan(from: "LOW", to: "LMC")!
        precondition(ealBranch.changes == 1 && ealBranch.legs.first?.stations.last?.id == "SHS")
        precondition(planner.plan(from: "ADM", to: "ADM") == nil)
        precondition(planner.plan(from: "BAD", to: "ADM") == nil)
        precondition(planner.plan(from: "ADM", to: "AIR") == nil)
        precondition(planner.patternsByLine["AEL"] == nil)
        precondition(!planner.stations.contains { ["AIR", "AWE"].contains($0.id) })
        // Validate continuity, direction and actual published adjacency across
        // representative interchanges, termini and branches in both directions.
        let sample = ["TSW", "DIS", "ADM", "HOK", "TUC", "POA", "LHP", "LOW", "LMC", "TUM", "WKS", "SOH"]
        var checked = 0
        for from in sample {
            for to in sample where from != to {
                guard let route = planner.plan(from: from, to: to) else { fatalError("Missing \(from) -> \(to)") }
                precondition(route.legs.first?.stations.first?.id == from)
                precondition(route.legs.last?.stations.last?.id == to)
                for (a, b) in zip(route.legs, route.legs.dropFirst()) {
                    precondition(a.stations.last?.id == b.stations.first?.id)
                }
                for leg in route.legs {
                    precondition(leg.stations.count > 1 && leg.lineID != "AEL")
                    let ids = leg.pattern.stations.map(\.id)
                    let start = ids.firstIndex(of: leg.stations.first!.id)!
                    precondition(Array(ids[start..<(start + leg.stations.count)]) == leg.stations.map(\.id))
                }
                checked += 1
            }
        }
        // Synthetic network proves the ranking favours fewer changes over a
        // shorter two-train option, then fewer stops among equal-change options.
        let fixture = """
        line,pattern,code,id,tc,en,seq
        A,UT,S,1,S,S,1
        A,UT,M,2,M,M,2
        A,UT,N,3,N,N,3
        A,UT,T,4,T,T,4
        B,UT,S,1,S,S,1
        B,UT,X,5,X,X,2
        C,UT,X,5,X,X,1
        C,UT,T,4,T,T,2
        D,UT,S,1,S,S,1
        D,UT,T,4,T,T,2
        """
        let fewerChanges = try MTRJourneyPlanner(csv: fixture, lineIDs: ["A", "B", "C"])
        precondition(fewerChanges.plan(from: "S", to: "T")?.legs.first?.lineID == "A")
        let fewerStops = try MTRJourneyPlanner(csv: fixture, lineIDs: ["A", "B", "C", "D"])
        precondition(fewerStops.plan(from: "S", to: "T")?.legs.first?.lineID == "D")
        print("Journey planner checks passed: \(checked) sample journeys, Disneyland and branch changes, exclusions, continuity and ranking.")
    }
}
