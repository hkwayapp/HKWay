import CoreLocation

enum RouteStopLocationResolver {
    static func location(for stop: JourneyStopEntity, journeyID: String?,
                         references: [OperatorStopReferenceEntity]) -> CLLocation? {
        // Match the journey and sequence, never just a similar stop name.
        // Stable ordering also makes joint-operator selection deterministic.
        if let journeyID {
            for reference in references.filter({ $0.journeyId == journeyID && $0.sequence == stop.sequence })
                .sorted(by: { $0.id < $1.id }) {
                if let latitude = reference.operatorLatitude, let longitude = reference.operatorLongitude,
                   let location = validLocation(latitude: latitude, longitude: longitude) {
                    return location
                }
            }
        }
        guard let physicalStop = stop.stop else { return nil }
        return validLocation(latitude: physicalStop.latitude, longitude: physicalStop.longitude)
    }

    private static func validLocation(latitude: Double, longitude: Double) -> CLLocation? {
        guard latitude.isFinite, longitude.isFinite,
              CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude)),
              latitude != 0 || longitude != 0 else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }
}
