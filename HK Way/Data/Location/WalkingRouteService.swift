//
//  WalkingRouteService.swift
//  HK Way
//
//  A single source of truth for pedestrian legs used by the route planner.
//  Values come from Apple Maps routing rather than straight-line estimates.
//

import CoreLocation
import MapKit

struct WalkingRoute: Equatable {
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval

    var roundedMinutes: Int {
        max(1, Int((expectedTravelTime / 60).rounded()))
    }
}

enum WalkingRouteService {
    enum RouteError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "A pedestrian route is not available for these locations."
        }
    }

    static func route(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> WalkingRoute {
        guard CLLocationCoordinate2DIsValid(origin),
              CLLocationCoordinate2DIsValid(destination) else {
            throw RouteError.unavailable
        }

        let request = MKDirections.Request()
        request.source = mapItem(at: origin)
        request.destination = mapItem(at: destination)
        request.transportType = .walking

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw RouteError.unavailable
        }
        return WalkingRoute(
            distance: route.distance,
            expectedTravelTime: route.expectedTravelTime
        )
    }

    private static func mapItem(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
        MKMapItem(
            location: CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            address: nil
        )
    }
}
