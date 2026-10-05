import Foundation

@main
struct BuddhaBusConnectionChecks {
    static func main() throws {
        for number in ["2", "21", "23"] {
            precondition(BuddhaBusConnection.matches(number: number, operatorIDs: ["NLB"], endpointIDs: ["11013"]))
            precondition(!BuddhaBusConnection.matches(number: number, operatorIDs: ["KMB"], endpointIDs: ["11013"]))
            precondition(!BuddhaBusConnection.matches(number: number, operatorIDs: ["NLB"], endpointIDs: ["other"]))
            precondition(!BuddhaBusConnection.matches(number: number, operatorIDs: ["NLB"], endpointIDs: []))
        }
        for number in ["1R", "2S", "21S", "23S", "23A", ""] {
            precondition(!BuddhaBusConnection.matches(number: number, operatorIDs: ["NLB"], endpointIDs: ["11013"]))
        }

        // Optionally check the actual local open-data snapshot without a download.
        if CommandLine.arguments.count > 1 {
            struct Route: Decodable { let id: String; let number: String; let operatorIds: [String] }
            struct Stop: Decodable { let journeyId: String; let stopId: String; let sequence: Int }
            let base = URL(fileURLWithPath: CommandLine.arguments[1])
            let routes = try JSONDecoder().decode([Route].self, from: Data(contentsOf: base.appendingPathComponent("routes.json")))
            let stops = try JSONDecoder().decode([Stop].self, from: Data(contentsOf: base.appendingPathComponent("journey_stops.json")))
            let journeys = Dictionary(grouping: stops, by: \.journeyId)
            var endpointsByRoute: [String: [String]] = [:]
            for (id, stops) in journeys {
                let routeID = String(id.split(separator: "-")[0])
                let ordered = stops.sorted { $0.sequence < $1.sequence }
                endpointsByRoute[routeID, default: []] += [ordered.first?.stopId, ordered.last?.stopId].compactMap { $0 }
            }
            let matches = routes.filter {
                BuddhaBusConnection.matches(number: $0.number, operatorIDs: $0.operatorIds,
                                             endpointIDs: endpointsByRoute[$0.id] ?? [])
            }
            precondition(Set(matches.map(\.id)) == ["1725", "1726", "1727"])
            precondition(matches.count == 3)
        }
        print("Big Buddha route checks passed: regular routes, operator/terminus guards and special-service exclusions")
    }
}
