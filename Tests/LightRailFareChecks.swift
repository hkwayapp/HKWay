import Foundation

@main
struct LightRailFareChecks {
    static func main() throws {
        let fares = try LightRailFares.parse(String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))
        let stopsCSV = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
        precondition(fares.count == 68 * 67)
        precondition(fares["1|1"] == nil)
        precondition(fares["1|10"]?.octopus == Decimal(string: "5.10"))
        precondition(fares["1|10"]?.singleJourney == Decimal(string: "5.50"))
        for route in ["505", "507", "610", "614", "614P", "615", "615P", "705", "706", "751", "761P"] {
            for journey in try LightRailStops.parse(stopsCSV, routeID: route) {
                for index in journey.stops.indices {
                    let origin = journey.stops[index]
                    let destinations = journey.destinations(after: index)
                    precondition(!destinations.contains { $0.stationID == origin.stationID })
                    if journey.id == "loop" {
                        precondition(destinations.count == 14)
                        precondition(Set(destinations.map(\.stationID)).count == 14)
                    } else if index == journey.stops.count - 1 {
                        precondition(destinations.isEmpty)
                    }
                    for destination in destinations {
                        let key = LightRailFares.key(from: origin.stationID, to: destination.stationID)
                        precondition(fares[key] != nil, "Missing fare: \(key)")
                    }
                }
            }
        }
        print("PASS: 4,556 fare pairs, adult Octopus/single fares, all route destinations, loop wraparound and no same-stop fares.")
    }
}
