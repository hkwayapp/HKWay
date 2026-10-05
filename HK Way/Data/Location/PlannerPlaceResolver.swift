//
//  PlannerPlaceResolver.swift
//  HK Way
//
//  Resolves stations and piers for planner walking legs using Apple Maps.
//

import CoreLocation
import MapKit

enum PlannerPlaceResolver {
    enum ResolverError: LocalizedError {
        case notFound

        var errorDescription: String? {
            "This location could not be found in Apple Maps."
        }
    }

    static func coordinate(
        for query: String,
        near expectedCoordinate: CLLocationCoordinate2D? = nil
    ) async throws -> CLLocationCoordinate2D {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
            span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
        )

        let response = try await MKLocalSearch(request: request).start()
        let items = response.mapItems.filter {
            CLLocationCoordinate2DIsValid($0.location.coordinate)
        }
        let item: MKMapItem?
        if let expectedCoordinate {
            let expectedLocation = CLLocation(
                latitude: expectedCoordinate.latitude,
                longitude: expectedCoordinate.longitude
            )
            item = items.min { first, second in
                expectedLocation.distance(from: first.location)
                    < expectedLocation.distance(from: second.location)
            }
        } else {
            item = items.first
        }

        guard let item,
              CLLocationCoordinate2DIsValid(item.location.coordinate) else {
            throw ResolverError.notFound
        }
        return item.location.coordinate
    }
}
