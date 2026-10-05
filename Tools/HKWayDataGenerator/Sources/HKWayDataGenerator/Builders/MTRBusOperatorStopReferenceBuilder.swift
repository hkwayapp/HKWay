//
//  MTRBusOperatorStopReferenceBuilder.swift
//  HK Way
//

import Foundation

struct MTRBusOperatorStopReferenceBuildResult {

    let routeNumber: String
    let references: [OperatorStopReference]
    let direction: String
    let coverage: Double
    let averageDistanceMeters: Double
}

struct MTRBusOperatorStopReferenceBuilder {

    private let aligner =
        MTRBusStopSequenceAligner()

    func buildAll(
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop]
    ) async throws
        -> [MTRBusOperatorStopReferenceBuildResult] {

        let officialStops = try await
            MTRBusStopCSVReader().fetch()

        return buildAll(
            routes: routes,
            journeys: journeys,
            journeyStops: journeyStops,
            stops: stops,
            officialStops: officialStops
        )
    }

    func buildAll(
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop],
        officialStops: [MTRBusStopRecord]
    ) -> [MTRBusOperatorStopReferenceBuildResult] {

        let officialRouteNumbers = Set(
            officialStops.map { $0.routeId.uppercased() }
        )
        let routeNumbers = Set(
            routes
                .filter {
                    $0.supportsOperator("LRTFeeder")
                }
                .map { $0.number.uppercased() }
        )
        .intersection(officialRouteNumbers)
        .sorted()

        return routeNumbers.flatMap { routeNumber in
            build(
                routeNumber: routeNumber,
                routes: routes,
                journeys: journeys,
                journeyStops: journeyStops,
                stops: stops,
                officialStops: officialStops
            )
        }
    }

    func build(
        routeNumber: String,
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop]
    ) async throws
        -> [MTRBusOperatorStopReferenceBuildResult] {

        let officialStops = try await
            MTRBusStopCSVReader().fetch()

        return build(
            routeNumber: routeNumber,
            routes: routes,
            journeys: journeys,
            journeyStops: journeyStops,
            stops: stops,
            officialStops: officialStops
        )
    }

    func build(
        routeNumber: String,
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop],
        officialStops: [MTRBusStopRecord]
    ) -> [MTRBusOperatorStopReferenceBuildResult] {

        let matchingRoutes = routes.filter {
            $0.supportsOperator("LRTFeeder") &&
            $0.number.caseInsensitiveCompare(
                routeNumber
            ) == .orderedSame
        }

        let officialRouteStops = officialStops.filter {
            $0.routeId.caseInsensitiveCompare(
                routeNumber
            ) == .orderedSame
        }

        let candidatesByDirection = Dictionary(
            grouping: officialRouteStops,
            by: {
                MTRBusDirectionKey(
                    referenceId: $0.referenceId,
                    direction: $0.direction
                )
            }
        )

        let stopLookup = Dictionary(
            uniqueKeysWithValues:
                stops.map { ($0.id, $0) }
        )

        var results:
            [MTRBusOperatorStopReferenceBuildResult] = []

        for route in matchingRoutes {
            let routeJourneys = journeys.filter {
                $0.routeId == route.id
            }

            for journey in routeJourneys {
                let localStops = journeyStops.filter {
                    $0.journeyId == journey.id
                }

                let candidates = candidatesByDirection.map {
                    key,
                    officialDirectionStops in

                    MTRBusCandidate(
                        direction: key.direction,
                        alignment: aligner.align(
                            transitGoStops: localStops,
                            mtrBusStops:
                                officialDirectionStops,
                            localStopLookup:
                                stopLookup
                        )
                    )
                }
                .sorted(by: ranksBefore)

                guard
                    let winner = candidates.first,
                    winner.alignment
                        .transitGoCoverage >= 0.55,
                    let averageDistance =
                        winner.alignment
                            .averageDistanceMeters,
                    averageDistance <= 350,
                    winner.alignment
                        .matchedPairs.count >= 2
                else {
                    continue
                }

                let references = winner.alignment
                    .matchedPairs
                    .map { pair in
                        OperatorStopReference(
                            operatorId: "LRTFeeder",
                            journeyId: journey.id,
                            stopId:
                                pair.transitGoStop.stopId,
                            sequence:
                                pair.transitGoStop.sequence,
                            operatorStopId:
                                pair.mtrBusStop.stopId,
                            operatorServiceType:
                                routeNumber,
                            operatorDirection:
                                winner.direction
                        )
                    }
                    .sorted {
                        $0.sequence < $1.sequence
                    }

                results.append(
                    MTRBusOperatorStopReferenceBuildResult(
                        routeNumber: routeNumber,
                        references: references,
                        direction: winner.direction,
                        coverage: winner.alignment
                            .transitGoCoverage,
                        averageDistanceMeters:
                            averageDistance
                    )
                )
            }
        }

        return results.sorted {
            ($0.references.first?.journeyId ?? "") <
                ($1.references.first?.journeyId ?? "")
        }
    }

    private func ranksBefore(
        _ lhs: MTRBusCandidate,
        _ rhs: MTRBusCandidate
    ) -> Bool {

        if lhs.alignment.transitGoCoverage !=
            rhs.alignment.transitGoCoverage {
            return lhs.alignment.transitGoCoverage >
                rhs.alignment.transitGoCoverage
        }

        if lhs.alignment.matchedPairs.count !=
            rhs.alignment.matchedPairs.count {
            return lhs.alignment.matchedPairs.count >
                rhs.alignment.matchedPairs.count
        }

        return (lhs.alignment.averageDistanceMeters ??
            .infinity) <
            (rhs.alignment.averageDistanceMeters ??
                .infinity)
    }
}

private struct MTRBusCandidate {
    let direction: String
    let alignment: MTRBusStopSequenceAlignment
}

private struct MTRBusDirectionKey: Hashable {
    let referenceId: String
    let direction: String
}
