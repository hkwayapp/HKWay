import Foundation
import CoreLocation

@main enum RouteStopLocationChecks {
    static func main() {
        // KMB 68M inbound, checked 2026-08-31: YL394 then YL404.
        let mallII = CLLocation(latitude: 22.446660, longitude: 114.035043)
        let mallI = CLLocation(latitude: 22.445065, longitude: 114.036445)
        func stop(_ sequence: Int, name: String, generic: CLLocation) -> JourneyStopEntity {
            let result = JourneyStopEntity(id: "stop\(sequence)", sequence: sequence)
            result.stop = StopEntity(id: name, latitude: generic.coordinate.latitude,
                longitude: generic.coordinate.longitude, nameEnglish: name, nameSimplified: name, nameTraditional: name)
            return result
        }
        func reference(_ sequence: Int, location: CLLocation, journey: String = "68M-I") -> OperatorStopReferenceEntity {
            OperatorStopReferenceEntity(operatorId: "KMB", journeyId: journey, stopId: "stop\(sequence)",
                sequence: sequence, operatorStopId: "KMB\(sequence)",
                operatorLatitude: location.coordinate.latitude, operatorLongitude: location.coordinate.longitude,
                operatorServiceType: "1", operatorDirection: "I")
        }
        // Deliberately wrong generic coordinates prove the overrides are used.
        let stops = [stop(4, name: "YOHO MALL II", generic: mallI), stop(5, name: "YOHO MALL I", generic: mallII)]
        let references = [reference(4, location: mallI, journey: "another-route"),
                          reference(4, location: mallII), reference(5, location: mallI)]
        func nearest(_ user: CLLocation) -> Int {
            stops.min {
                user.distance(from: RouteStopLocationResolver.location(for: $0, journeyID: "68M-I", references: references)!) <
                user.distance(from: RouteStopLocationResolver.location(for: $1, journeyID: "68M-I", references: references)!)
            }!.sequence
        }
        precondition(nearest(mallII) == 4 && nearest(mallI) == 5)
        let fallback = RouteStopLocationResolver.location(for: stops[0], journeyID: "missing", references: references)!
        precondition(fallback.distance(from: mallI) < 0.01)
        let invalid = reference(4, location: CLLocation(latitude: 0, longitude: 0))
        precondition(RouteStopLocationResolver.location(for: stops[0], journeyID: "68M-I", references: [invalid])!.distance(from: mallI) < 0.01)
        let missing = JourneyStopEntity(id: "missing", sequence: 99)
        precondition(RouteStopLocationResolver.location(for: missing, journeyID: nil, references: []) == nil)
        print("Route-stop location checks passed: Yoho Mall II/I, journey isolation, invalid overrides and fallback.")
    }
}
