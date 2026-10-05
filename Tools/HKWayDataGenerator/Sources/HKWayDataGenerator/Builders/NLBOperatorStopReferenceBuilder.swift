//
//  NLBOperatorStopReferenceBuilder.swift
//  HK Way
//

import Foundation

struct NLBOperatorStopReferenceBuildResult {

    let routeId: String
    let references: [OperatorStopReference]
    let coverage: Double
    let averageDistanceMeters: Double
    let isAmbiguous: Bool
}

struct NLBOperatorStopReferenceFullBuildResult {

    let references: [OperatorStopReference]
    let matchedJourneys: Int
    let unmatchedRoutes: [String]
    let unmatchedJourneys: [String]
    let ambiguousJourneys: [String]
    let rejectedJourneys: [String]
}

struct NLBOperatorStopReferenceBuilder {

    private let sequenceAligner =
        NLBStopSequenceAligner()

    private let routeAPI =
        NLBRouteAPI()

    private let routeStopAPI =
        NLBRouteStopAPI()

    func buildAll(
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop]
    ) async throws
        -> NLBOperatorStopReferenceFullBuildResult {

        let localRouteNumbers = Set(
            routes
                .filter {
                    $0.supportsOperator("NLB")
                }
                .map {
                    $0.number.uppercased()
                }
        )

        let nlbRoutes =
            try await routeAPI.fetchAll()
                .filter {
                    localRouteNumbers.contains(
                        $0.routeNumber.uppercased()
                    )
                }

        var nlbStopsByRouteId:
            [String: [NLBRouteStopRecord]] = [:]

        for nlbRoute in nlbRoutes {
            nlbStopsByRouteId[nlbRoute.routeId] =
                try await routeStopAPI.fetch(
                    routeId: nlbRoute.routeId
                )
        }

        return buildAll(
            routes: routes,
            journeys: journeys,
            journeyStops: journeyStops,
            stops: stops,
            nlbRoutes: nlbRoutes,
            nlbStopsByRouteId:
                nlbStopsByRouteId
        )
    }

    func buildAll(
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop],
        nlbRoutes: [NLBRouteRecord],
        nlbStopsByRouteId:
            [String: [NLBRouteStopRecord]]
    ) -> NLBOperatorStopReferenceFullBuildResult {

        let nlbTransitRoutes =
            routes.filter {
                $0.supportsOperator("NLB")
            }

        let journeysByRoute =
            Dictionary(
                grouping: journeys,
                by: \.routeId
            )

        let nlbRoutesByNumber =
            Dictionary(
                grouping: nlbRoutes,
                by: {
                    $0.routeNumber.uppercased()
                }
            )

        var references:
            [OperatorStopReference] = []

        var matchedJourneys = 0
        var unmatchedRoutes: [String] = []
        let unmatchedJourneys: [String] = []
        var ambiguousJourneys: [String] = []
        var rejectedJourneys: [String] = []

        for route in nlbTransitRoutes {

            let apiRoutes =
                nlbRoutesByNumber[
                    route.number.uppercased()
                ] ?? []

            guard !apiRoutes.isEmpty else {
                unmatchedRoutes.append(
                    "\(route.id) | \(route.number)"
                )
                continue
            }

            let routeJourneys =
                journeysByRoute[route.id] ?? []

            guard !routeJourneys.isEmpty else {
                unmatchedRoutes.append(
                    "\(route.id) | \(route.number)"
                )
                continue
            }

            for journey in routeJourneys {

                guard let result = build(
                    route: route,
                    journey: journey,
                    journeyStops: journeyStops,
                    stops: stops,
                    nlbRoutes: apiRoutes,
                    nlbStopsByRouteId:
                        nlbStopsByRouteId
                ) else {
                    rejectedJourneys.append(
                        journey.id
                    )
                    continue
                }

                guard !result.isAmbiguous else {
                    ambiguousJourneys.append(
                        journey.id
                    )
                    continue
                }

                references.append(
                    contentsOf: result.references
                )
                matchedJourneys += 1
            }
        }

        return NLBOperatorStopReferenceFullBuildResult(
            references: references.sorted {
                if $0.journeyId != $1.journeyId {
                    return $0.journeyId < $1.journeyId
                }

                return $0.sequence < $1.sequence
            },
            matchedJourneys: matchedJourneys,
            unmatchedRoutes:
                unmatchedRoutes.sorted(),
            unmatchedJourneys:
                unmatchedJourneys.sorted(),
            ambiguousJourneys:
                ambiguousJourneys.sorted(),
            rejectedJourneys:
                rejectedJourneys.sorted()
        )
    }

    func build(
        route: Route,
        journey: Journey,
        journeyStops: [JourneyStop],
        stops: [Stop],
        nlbRoutes: [NLBRouteRecord],
        nlbStopsByRouteId:
            [String: [NLBRouteStopRecord]]
    ) -> NLBOperatorStopReferenceBuildResult? {

        guard
            route.supportsOperator("NLB"),
            journey.routeId == route.id
        else {
            return nil
        }

        let localJourneyStops =
            journeyStops
                .filter {
                    $0.journeyId == journey.id
                }
                .sorted {
                    $0.sequence < $1.sequence
                }

        guard !localJourneyStops.isEmpty else {
            return nil
        }

        let localStopLookup =
            Dictionary(
                uniqueKeysWithValues:
                    stops.map {
                        ($0.id, $0)
                    }
            )

        let candidates =
            nlbRoutes
                .filter {
                    $0.routeNumber
                        .caseInsensitiveCompare(
                            route.number
                        ) == .orderedSame
                }
                .compactMap { nlbRoute in

                    guard let nlbStops =
                        nlbStopsByRouteId[
                            nlbRoute.routeId
                        ],
                        !nlbStops.isEmpty
                    else {
                        return nil
                    }

                    let alignment =
                        sequenceAligner.align(
                            transitGoStops:
                                localJourneyStops,
                            nlbStops:
                                nlbStops,
                            localStopLookup:
                                localStopLookup
                        )

                    return candidate(
                        route: nlbRoute,
                        alignment: alignment,
                        transitGoStops:
                            localJourneyStops,
                        nlbStopCount:
                            nlbStops.count
                    )
                }
                .filter {
                    $0.matchedCount > 0
                }
                .sorted(by: ranksBefore)

        guard let winner = candidates.first else {
            return nil
        }

        guard
            winner.coverage >= 0.90,
            winner.matchedCount >= 2
        else {
            return nil
        }

        var isAmbiguous = false

        if candidates.count >= 2 {

            let runnerUp = candidates[1]

            isAmbiguous =
                abs(
                    winner.coverage -
                    runnerUp.coverage
                ) < 0.05 &&
                abs(
                    winner.matchedCount -
                    runnerUp.matchedCount
                ) <= 1 &&
                winner.endpointMatchCount ==
                    runnerUp.endpointMatchCount &&
                abs(
                    winner.averageDistanceMeters -
                    runnerUp.averageDistanceMeters
                ) < 20

        }

        let references =
            winner.alignment
                .matchedPairs
                .map { pair in
                    OperatorStopReference(
                        operatorId: "NLB",
                        journeyId: journey.id,
                        stopId:
                            pair.transitGoStop.stopId,
                        sequence:
                            pair.transitGoStop.sequence,
                        operatorStopId:
                            pair.nlbStop.stopId,
                        operatorServiceType:
                            winner.route.routeId,
                        operatorDirection:
                            journey.direction
                    )
                }
                .sorted {
                    $0.sequence < $1.sequence
                }

        return NLBOperatorStopReferenceBuildResult(
            routeId: winner.route.routeId,
            references: references,
            coverage: winner.coverage,
            averageDistanceMeters:
                winner.averageDistanceMeters,
            isAmbiguous: isAmbiguous
        )
    }

    private func candidate(
        route: NLBRouteRecord,
        alignment: NLBStopSequenceAlignment,
        transitGoStops: [JourneyStop],
        nlbStopCount: Int
    ) -> NLBCandidate {

        let distances =
            alignment.matchedPairs.map {
                $0.distanceMeters
            }

        let averageDistance: Double

        if distances.isEmpty {
            averageDistance = .infinity
        } else {
            averageDistance =
                distances.reduce(0, +) /
                Double(distances.count)
        }

        let firstHKWayStopId =
            transitGoStops.first?.stopId

        let lastHKWayStopId =
            transitGoStops.last?.stopId

        let firstEndpointMatches =
            alignment.matchedPairs.contains {
                $0.transitGoStop.stopId ==
                    firstHKWayStopId &&
                $0.nlbSequence == 1
            }

        let lastEndpointMatches =
            alignment.matchedPairs.contains {
                $0.transitGoStop.stopId ==
                    lastHKWayStopId &&
                $0.nlbSequence ==
                    nlbStopCount
            }

        let endpointMatchCount =
            (firstEndpointMatches ? 1 : 0) +
            (lastEndpointMatches ? 1 : 0)

        return NLBCandidate(
            route: route,
            alignment: alignment,
            matchedCount:
                alignment.matchedPairs.count,
            coverage:
                alignment.transitGoCoverage,
            endpointMatchCount:
                endpointMatchCount,
            averageDistanceMeters:
                averageDistance
        )
    }

    private func ranksBefore(
        _ lhs: NLBCandidate,
        _ rhs: NLBCandidate
    ) -> Bool {

        if lhs.coverage != rhs.coverage {
            return lhs.coverage > rhs.coverage
        }

        if lhs.matchedCount != rhs.matchedCount {
            return lhs.matchedCount >
                rhs.matchedCount
        }

        if lhs.endpointMatchCount !=
            rhs.endpointMatchCount {
            return lhs.endpointMatchCount >
                rhs.endpointMatchCount
        }

        if lhs.averageDistanceMeters !=
            rhs.averageDistanceMeters {
            return lhs.averageDistanceMeters <
                rhs.averageDistanceMeters
        }

        return lhs.route.routeId
            .localizedStandardCompare(
                rhs.route.routeId
            ) == .orderedAscending
    }
}

private struct NLBCandidate {

    let route: NLBRouteRecord
    let alignment: NLBStopSequenceAlignment
    let matchedCount: Int
    let coverage: Double
    let endpointMatchCount: Int
    let averageDistanceMeters: Double
}
