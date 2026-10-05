import Foundation
import CoreLocation

@main enum NearbyRadiusChecks {
    @MainActor static func main() async {
        func route(_ id: String, operatorID: String, meters: Double, name: String) -> RouteEntity {
            let route = RouteEntity(id: id, number: id, originEnglish: name, originTraditional: name,
                originSimplified: name, destinationEnglish: "Destination", destinationTraditional: "終點", destinationSimplified: "终点")
            route.operators = [OperatorEntity(id: operatorID, nameEnglish: operatorID,
                nameSimplified: operatorID, nameTraditional: operatorID)]
            let stop = StopEntity(id: "stop-" + id, latitude: 22.37 + meters / 111_195,
                longitude: 114.11, nameEnglish: name, nameSimplified: name, nameTraditional: name)
            let journey = JourneyEntity(id: "journey-" + id, direction: "O", serviceType: "1")
            let boarding = JourneyStopEntity(id: "boarding-" + id, sequence: 1)
            boarding.stop = stop
            journey.journeyStops = [boarding]
            route.journeys = [journey]
            return route
        }
        var routes = [
            route("GMB1", operatorID: "GMB", meters: 10, name: "Minibus Terminus"),
            route("KMB1", operatorID: "KMB", meters: 180, name: "Market Street"),
            route("CTB1", operatorID: "CTB", meters: 300, name: "Library"),
            route("OUT", operatorID: "KMB", meters: 500, name: "Outside Radius")
        ]
        for index in 0..<110 {
            routes.append(route("EXTRA\(index)", operatorID: "GMB", meters: 40, name: "Minibus Terminus"))
        }
        let prepared = await NearbyRouteIndex.prepare(routes: routes, operatorStopReferences: [])
        precondition(NearbySearchRadius(storedValue: 0) == .close)
        precondition(NearbySearchRadius(storedValue: 200) == .medium)
        precondition(NearbySearchRadius(storedValue: 400) == .wide)
        for (radius, count) in [(100, 111), (200, 112), (400, 113), (100, 111)] {
            let results = prepared.index.nearbyJourneyStops(latitude: 22.37, longitude: 114.11,
                maximumDistanceMeters: Double(radius))
            precondition(results.count == count)
            precondition(results.allSatisfy { $0.distanceMeters <= Double(radius) })
        }
        var previousIDs: Set<String>?
        for offset in [-5.0, 0, 5] {
            let matches = prepared.index.nearbyJourneyStops(latitude: 22.37 + offset / 111_195,
                longitude: 114.11, maximumDistanceMeters: 400)
            precondition(matches.count == 113)
            precondition(Set(matches.map(\.operatorKey)) == Set(["GMB", "KMB", "CTB"]))
            precondition(!matches.contains { $0.routeNumber == "OUT" })
            precondition(zip(matches, matches.dropFirst()).allSatisfy { $0.distanceMeters <= $1.distanceMeters })
            let ids = Set(matches.map(\.journeyStopId))
            if let previousIDs { precondition(previousIDs == ids) }
            previousIDs = ids
        }
        let repeated = prepared.index.nearbyJourneyStops(latitude: 22.37, longitude: 114.11, maximumDistanceMeters: 400)
        let repeatedAgain = prepared.index.nearbyJourneyStops(latitude: 22.37, longitude: 114.11, maximumDistanceMeters: 400)
        precondition(repeated.map(\.journeyStopId) == repeatedAgain.map(\.journeyStopId))
        print("Nearby radius checks passed: 113 results, all three operators, different stop names, 400 m exclusion, GPS shifts and stable ordering.")
    }
}
