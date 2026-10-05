//
//  NearbyRouteResolver.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import Foundation
import CoreLocation

struct NearbyRouteMatch {

    let route: RouteEntity
    let journey: JourneyEntity
    let journeyStop: JourneyStopEntity
    let stop: StopEntity
    let distanceMeters: CLLocationDistance
}

struct NearbyRouteIndex: Sendable {

    private let candidates: [NearbyRouteCandidate]

    private init(candidates: [NearbyRouteCandidate]) {
        self.candidates = candidates
    }

    @MainActor
    static func prepare(
        routes: [RouteEntity],
        operatorStopReferences: [OperatorStopReferenceEntity]
    ) async -> NearbyRoutePreparation {
        var operatorCoordinates:
            [String: NearbyRouteCoordinate] = [:]

        for (index, reference) in
            operatorStopReferences.enumerated() {

            if let latitude = reference.operatorLatitude,
               let longitude = reference.operatorLongitude {
                let key =
                    "\(reference.journeyId)|\(reference.sequence)"

                if operatorCoordinates[key] == nil {
                    operatorCoordinates[key] =
                        NearbyRouteCoordinate(
                            latitude: latitude,
                            longitude: longitude
                        )
                }
            }

            if index.isMultiple(of: 1_000) {
                await Task.yield()

                if Task.isCancelled {
                    return NearbyRoutePreparation(
                        index: NearbyRouteIndex(
                            candidates: []
                        ),
                        matchesByJourneyStopId: [:]
                    )
                }
            }
        }

        var builtCandidates: [NearbyRouteCandidate] = []
        var matchesByJourneyStopId:
            [String: NearbyRouteMatch] = [:]

        for (routeIndex, route) in routes.enumerated() {
            let operatorKey = route.operators
                .map(\.id)
                .sorted()
                .joined(separator: "+")

            for journey in route.journeys {
                let destinationKey =
                    journey.destinationStop?.id
                    ?? route.destinationEnglish

                for journeyStop in journey.journeyStops {
                    guard let stop = journeyStop.stop else {
                        continue
                    }

                    let coordinate = operatorCoordinates[
                        "\(journey.id)|\(journeyStop.sequence)"
                    ] ?? NearbyRouteCoordinate(
                        latitude: stop.latitude,
                        longitude: stop.longitude
                    )

                    builtCandidates.append(
                        NearbyRouteCandidate(
                            journeyStopId: journeyStop.id,
                            stopId: stop.id,
                            stopName: stop.nameEnglish,
                            routeNumber: route.number,
                            operatorKey: operatorKey,
                            destinationKey: destinationKey,
                            coordinate: coordinate
                        )
                    )

                    matchesByJourneyStopId[journeyStop.id] =
                        NearbyRouteMatch(
                            route: route,
                            journey: journey,
                            journeyStop: journeyStop,
                            stop: stop,
                            distanceMeters: 0
                        )
                }
            }

            if routeIndex.isMultiple(of: 10) {
                await Task.yield()

                if Task.isCancelled {
                    return NearbyRoutePreparation(
                        index: NearbyRouteIndex(
                            candidates: []
                        ),
                        matchesByJourneyStopId: [:]
                    )
                }
            }
        }

        return NearbyRoutePreparation(
            index: NearbyRouteIndex(
                candidates: builtCandidates
            ),
            matchesByJourneyStopId:
                matchesByJourneyStopId
        )
    }

    nonisolated func nearbyJourneyStops(
        latitude: Double,
        longitude: Double,
        maximumDistanceMeters: CLLocationDistance
    ) -> [NearbyRouteCandidateResult] {
        var nearbyResults: [NearbyRouteCandidateResult] = []

        for candidate in candidates {
            let distance = candidate.coordinate.distance(
                toLatitude: latitude,
                longitude: longitude
            )

            guard distance <= maximumDistanceMeters else {
                continue
            }

            let result = NearbyRouteCandidateResult(
                journeyStopId: candidate.journeyStopId,
                stopId: candidate.stopId,
                stopName: candidate.stopName,
                routeNumber: candidate.routeNumber,
                operatorKey: candidate.operatorKey,
                destinationKey: candidate.destinationKey,
                coordinate: candidate.coordinate,
                distanceMeters: distance
            )

            nearbyResults.append(result)
        }

        var deduplicated:
            [String: NearbyRouteCandidateResult] = [:]

        // Keep every physical boarding stop in range, regardless of its name
        // or operator. A nearer stop must not hide a different nearby stop.
        for result in nearbyResults {
            let key = [
                result.operatorKey,
                result.routeNumber,
                result.destinationKey,
                result.stopId
            ].joined(separator: "|")

            if let existing = deduplicated[key] {
                if existing.distanceMeters < result.distanceMeters ||
                    (existing.distanceMeters == result.distanceMeters && existing.journeyStopId < result.journeyStopId) {
                    continue
                }
            }

            deduplicated[key] = result
        }

        // No global result cap: it can hide operators before the UI filter.
        return deduplicated.values.sorted {
            $0.distanceMeters != $1.distanceMeters
                ? $0.distanceMeters < $1.distanceMeters
                : $0.journeyStopId < $1.journeyStopId
        }
    }
}

struct NearbyRoutePreparation {
    let index: NearbyRouteIndex
    let matchesByJourneyStopId: [String: NearbyRouteMatch]
}

private struct NearbyRouteCandidate: Sendable {
    let journeyStopId: String
    let stopId: String
    let stopName: String
    let routeNumber: String
    let operatorKey: String
    let destinationKey: String
    let coordinate: NearbyRouteCoordinate
}

struct NearbyRouteCandidateResult: Sendable {
    let journeyStopId: String
    let stopId: String
    let stopName: String
    let routeNumber: String
    let operatorKey: String
    let destinationKey: String
    fileprivate let coordinate: NearbyRouteCoordinate
    let distanceMeters: CLLocationDistance
}


fileprivate struct NearbyRouteCoordinate: Sendable {
    let latitude: Double
    let longitude: Double

    nonisolated func distance(
        toLatitude targetLatitude: Double,
        longitude targetLongitude: Double
    ) -> CLLocationDistance {
        let earthRadius = 6_371_000.0
        let latitudeDelta = (targetLatitude - latitude) * .pi / 180
        let longitudeDelta = (targetLongitude - longitude) * .pi / 180
        let startLatitude = latitude * .pi / 180
        let targetLatitude = targetLatitude * .pi / 180

        let a = pow(sin(latitudeDelta / 2), 2) +
            cos(startLatitude) * cos(targetLatitude) *
            pow(sin(longitudeDelta / 2), 2)

        return earthRadius * 2 * atan2(
            sqrt(a),
            sqrt(1 - a)
        )
    }

    nonisolated func distance(
        to other: NearbyRouteCoordinate
    ) -> CLLocationDistance {
        distance(
            toLatitude: other.latitude,
            longitude: other.longitude
        )
    }
}

struct NearbyRouteResolver {

    func nearbyRoutes(
        from routes: [RouteEntity],
        stops: [StopEntity],
        operatorStopReferences:
            [OperatorStopReferenceEntity] = [],
        userLocation: CLLocation,
        maximumDistanceMeters: CLLocationDistance = 500,
        maximumRoutes: Int = 100
    ) -> [NearbyRouteMatch] {

        var distanceByStopId:
            [String: CLLocationDistance] = [:]

        distanceByStopId.reserveCapacity(
            stops.count
        )

        for stop in stops {

            let stopLocation =
                CLLocation(
                    latitude: stop.latitude,
                    longitude: stop.longitude
                )

            let distance =
                userLocation.distance(
                    from: stopLocation
                )

            distanceByStopId[stop.id] =
                distance
        }

        var matches:
            [NearbyRouteMatch] = []

        let operatorCoordinateByJourneyStop =
            Dictionary(
                operatorStopReferences.compactMap {
                    reference ->
                        (String, CLLocation)? in

                    guard
                        let latitude =
                            reference.operatorLatitude,
                        let longitude =
                            reference.operatorLongitude
                    else {
                        return nil
                    }

                    let key =
                        "\(reference.journeyId)|\(reference.sequence)"

                    return (
                        key,
                        CLLocation(
                            latitude: latitude,
                            longitude: longitude
                        )
                    )
                },
                uniquingKeysWith: { first, _ in first }
            )

        matches.reserveCapacity(
            routes.reduce(0) {
                $0 + $1.journeys.count
            }
        )

        for route in routes {

            for journey in route.journeys {

                var bestJourneyStop:
                    JourneyStopEntity?

                var bestStop:
                    StopEntity?

                var bestDistance =
                    CLLocationDistance.greatestFiniteMagnitude

                for journeyStop in journey.journeyStops {

                    guard let stop =
                        journeyStop.stop
                    else {
                        continue
                    }

                    let referenceKey =
                        "\(journey.id)|\(journeyStop.sequence)"

                    let distance =
                        operatorCoordinateByJourneyStop[
                            referenceKey
                        ]
                        .map {
                            userLocation.distance(from: $0)
                        }
                        ?? distanceByStopId[stop.id]
                        ?? CLLocationDistance
                            .greatestFiniteMagnitude

                    if distance < bestDistance {

                        bestDistance =
                            distance

                        bestJourneyStop =
                            journeyStop

                        bestStop =
                            stop
                    }
                }

                guard
                    bestDistance <= maximumDistanceMeters,
                    let journeyStop = bestJourneyStop,
                    let stop = bestStop
                else {
                    continue
                }

                matches.append(
                    NearbyRouteMatch(
                        route: route,
                        journey: journey,
                        journeyStop: journeyStop,
                        stop: stop,
                        distanceMeters: bestDistance
                    )
                )
            }
        }

        var deduplicated:
            [String: NearbyRouteMatch] = [:]

        for match in matches {

            let operatorKey =
                match.route.operators
                    .map {
                        $0.id
                    }
                    .sorted()
                    .joined(
                        separator: "+"
                    )

            let destinationKey =
                match.journey
                    .destinationStop?
                    .id
                ??
                match.route
                    .destinationEnglish

            let key =
                [
                    operatorKey,
                    match.route.number,
                    destinationKey
                ]
                .joined(
                    separator: "|"
                )

            if let existing =
                deduplicated[key] {

                if match.distanceMeters <
                    existing.distanceMeters {

                    deduplicated[key] =
                        match
                }

            } else {

                deduplicated[key] =
                    match
            }
        }

        matches =
            Array(
                deduplicated.values
            )
        
        matches.sort {
            $0.distanceMeters <
                $1.distanceMeters
        }

        return Array(
            matches.prefix(
                maximumRoutes
            )
        )
    }
}
