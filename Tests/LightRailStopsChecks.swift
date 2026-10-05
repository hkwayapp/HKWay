import Foundation

// Run with LightRailStops.swift as a standalone Swift executable.
@main
struct LightRailStopsChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let routes = ["505", "507", "610", "614", "614P", "615", "615P", "705", "706", "751", "761P"]
        for route in routes {
            let journeys = try LightRailStops.parse(csv, routeID: route)
            let loop = route == "705" || route == "706"
            precondition(journeys.count == (loop ? 1 : 2))
            for journey in journeys {
                precondition(journey.stops.count > 2)
                precondition(journey.stops.allSatisfy { !$0.english.isEmpty && !$0.traditional.isEmpty && !$0.simplified.isEmpty })
                precondition(zip(journey.stops, journey.stops.dropFirst()).allSatisfy { $0.stationID != $1.stationID })
                if loop {
                    precondition(journey.stops.count == 16)
                    precondition(journey.stops.first?.stationID == journey.stops.last?.stationID)
                    precondition(Set(journey.stops.map(\.stationID)).count == 15)
                }
            }
            if !loop {
                precondition(journeys[0].stops.first?.stationID == journeys[1].stops.last?.stationID)
                precondition(journeys[0].stops.last?.stationID == journeys[1].stops.first?.stationID)
            }
        }
        let route505 = try LightRailStops.parse(csv, routeID: "505")
        precondition(route505[0].stops.contains { $0.english == "Shan King (South)" })
        precondition(!route505[1].stops.contains { $0.english == "Shan King (South)" })
        precondition(route505[1].stops.contains { $0.english == "Ming Kum" })
        let route761 = try LightRailStops.parse(csv, routeID: "761P")
        precondition(route761[1].stops.count == 14)
        print("PASS: 11 routes, both directions, 705/706 loops, 505 asymmetry, duplicate terminus removal.")
    }
}
