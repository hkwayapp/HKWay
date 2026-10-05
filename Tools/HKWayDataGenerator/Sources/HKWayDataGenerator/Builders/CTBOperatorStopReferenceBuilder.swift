//
//  CTBOperatorStopReferenceBuilder.swift
//  HK Way
//
//  Created by Ken on 15/8/2026.
//

import Foundation

struct CTBOperatorStopReferenceBuilder {

    private let sequenceAligner =
        CTBStopSequenceAligner()

    private let cache =
        CTBOperatorStopReferenceCache()

    // MARK: - Full Network

    func buildAll(
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop]
    ) async throws
        -> CTBOperatorStopReferenceBuildResult {

        let ctbRoutes =
            routes.filter {
                $0.supportsOperator("CTB")
            }

        let journeysByRoute =
            Dictionary(
                grouping: journeys,
                by: \.routeId
            )

        let journeyStopsByJourney =
            Dictionary(
                grouping: journeyStops,
                by: \.journeyId
            )

        let localStopLookup =
            Dictionary(
                uniqueKeysWithValues:
                    stops.map {
                        ($0.id, $0)
                    }
            )

            // MARK: - Prefetch CTB Network Data

            print("")
            print("*** CTB network prefetch ***")

            var allCTBStopIds:
                Set<String> = []

            let routeNumbers =
                Set(
                    ctbRoutes.map {
                        $0.number
                    }
                )

            print(
                "Unique CTB route numbers:",
                routeNumbers.count
            )

            for routeNumber in
                routeNumbers.sorted() {

                for direction in [
                    "outbound",
                    "inbound"
                ] {

                    do {

                        let routeStops =
                            try await cache.routeStops(
                                route:
                                    routeNumber,
                                direction:
                                    direction
                            )

                        for routeStop in routeStops {

                            allCTBStopIds.insert(
                                routeStop.stop
                            )
                        }

                    } catch {

                        print(
                            "CTB route-stop prefetch failed",
                            "| route:",
                            routeNumber,
                            "| direction:",
                            direction,
                            "| error:",
                            error
                        )
                    }
                }
            }

            print(
                "Unique CTB stop IDs:",
                allCTBStopIds.count
            )

            await cache.prefetchStops(
                stopIds:
                    allCTBStopIds,
                concurrency:
                    8
            )

            print("")
            print("*** CTB alignment phase ***")
            
            
        var references:
            [OperatorStopReference] = []

        var matchedJourneys = 0

        var unmatchedRoutes:
            [String] = []

        var unmatchedJourneys:
            [String] = []

        var ambiguousJourneys:
            [String] = []

        var rejectedJourneys:
            [String] = []

        for route in ctbRoutes {

            let routeJourneys =
                journeysByRoute[
                    route.id
                ] ?? []

            guard !routeJourneys.isEmpty else {

                unmatchedRoutes.append(
                    "\(route.id) | \(route.number)"
                )

                continue
            }

            for journey in routeJourneys {

                let localJourneyStops =
                    (
                        journeyStopsByJourney[
                            journey.id
                        ] ?? []
                    )
                    .sorted {
                        $0.sequence <
                            $1.sequence
                    }

                guard
                    !localJourneyStops.isEmpty
                else {

                    unmatchedJourneys.append(
                        "\(journey.id) | no journey stops"
                    )

                    continue
                }

                do {

                    guard let result =
                        try await buildCandidate(
                            route:
                                route,
                            journey:
                                journey,
                            localJourneyStops:
                                localJourneyStops,
                            localStopLookup:
                                localStopLookup
                        )
                    else {

                        unmatchedJourneys.append(
                            journey.id
                        )

                        continue
                    }

                    // Require strong HK Way coverage.
                    //
                    // CTB can contain additional stops
                    // that are not represented in the
                    // HK Way journey, so CTB-only
                    // gaps are allowed.

                    guard
                        result.score.coverage >= 0.90,
                        result.score.matchedCount >= 2
                    else {

                        rejectedJourneys.append(
                            "\(journey.id) | direction \(result.direction) | coverage \(String(format: "%.3f", result.score.coverage)) | matched \(result.score.matchedCount)"
                        )

                        continue
                    }

                    if result.isAmbiguous {

                        ambiguousJourneys.append(
                            journey.id
                        )

                        continue
                    }

                    references.append(
                        contentsOf:
                            result.references
                    )

                    matchedJourneys += 1

                } catch {

                    unmatchedJourneys.append(
                        "\(journey.id) | \(error)"
                    )
                }
            }
        }

        return CTBOperatorStopReferenceBuildResult(
            references:
                references,
            matchedJourneys:
                matchedJourneys,
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

    // MARK: - Single Journey Diagnostic

    func build(
        route: Route,
        journey: Journey,
        journeyStops: [JourneyStop],
        stops: [Stop]
    ) async throws
        -> [OperatorStopReference] {

        guard
            route.supportsOperator("CTB")
        else {
            return []
        }

        let localJourneyStops =
            journeyStops
                .filter {
                    $0.journeyId ==
                        journey.id
                }
                .sorted {
                    $0.sequence <
                        $1.sequence
                }

        guard
            !localJourneyStops.isEmpty
        else {
            return []
        }

        let localStopLookup =
            Dictionary(
                uniqueKeysWithValues:
                    stops.map {
                        ($0.id, $0)
                    }
            )

        let candidates =
            try await makeDirectionCandidates(
                route:
                    route,
                localJourneyStops:
                    localJourneyStops,
                localStopLookup:
                    localStopLookup
            )

        guard let winner =
            bestCandidate(
                from: candidates
            )
        else {

            print(
                "CTB direction unresolved",
                "| route:",
                route.number,
                "| journey:",
                journey.id
            )

            return []
        }

        print("")
        print("*** CTB journey diagnostic ***")
        print("Route:", route.number)
        print("Journey:", journey.id)

        print(
            "Selected direction:",
            winner.direction
        )

        print(
            "HK Way stops:",
            localJourneyStops.count
        )

        print("")
        print("*** CTB candidate scores ***")

        for candidate in candidates {

            print(
                "Direction:",
                candidate.direction,
                "| matched:",
                candidate.score.matchedCount,
                "| coverage:",
                String(
                    format: "%.3f",
                    candidate.score.coverage
                ),
                "| HK Way-only:",
                candidate.score
                    .transitGoOnlyCount,
                "| CTB-only:",
                candidate.score
                    .ctbOnlyCount,
                "| avg:",
                String(
                    format: "%.1f m",
                    candidate.score
                        .averageDistance
                ),
                "| max:",
                String(
                    format: "%.1f m",
                    candidate.score
                        .maximumDistance
                )
            )
        }

            if !winner.alignment.transitGoOnly.isEmpty {

                print("")
                print("*** HK Way-only stops ***")

                for journeyStop in
                    winner.alignment.transitGoOnly {

                    let stop =
                        localStopLookup[
                            journeyStop.stopId
                        ]

                    print(
                        "seq:",
                        journeyStop.sequence,
                        "| stop:",
                        journeyStop.stopId,
                        "|",
                        stop?.nameEnglish ?? "unknown"
                    )
                }
            }

            if !winner.alignment.ctbOnly.isEmpty {

                print("")
                print("*** CTB-only stops ***")

                for routeStop in
                    winner.alignment.ctbOnly {

                    let stop =
                        try? await cache.stop(
                            stopId:
                                routeStop.stop
                        )

                    print(
                        "seq:",
                        routeStop.sequence,
                        "| stop:",
                        routeStop.stop,
                        "|",
                        stop?.nameEnglish ?? "unknown"
                    )
                }
            }
            
            
            
        print("")
        print("*** Selected CTB alignment ***")

        print(
            "Matched:",
            winner.score.matchedCount
        )

        print(
            "HK Way-only:",
            winner.score
                .transitGoOnlyCount
        )

        print(
            "CTB-only:",
            winner.score
                .ctbOnlyCount
        )

        print(
            "Average distance:",
            String(
                format: "%.1f m",
                winner.score
                    .averageDistance
            )
        )

        print(
            "Maximum distance:",
            String(
                format: "%.1f m",
                winner.score
                    .maximumDistance
            )
        )

        return makeReferences(
            from:
                winner,
            journey:
                journey
        )
    }

    // MARK: - Build Candidate

    private func buildCandidate(
        route: Route,
        journey: Journey,
        localJourneyStops: [JourneyStop],
        localStopLookup: [String: Stop]
    ) async throws
        -> CTBBuildCandidateResult? {

        let candidates =
            try await makeDirectionCandidates(
                route:
                    route,
                localJourneyStops:
                    localJourneyStops,
                localStopLookup:
                    localStopLookup
            )

        guard let winner =
            bestCandidate(
                from: candidates
            )
        else {
            return nil
        }

        let references =
            makeReferences(
                from:
                    winner,
                journey:
                    journey
            )

        let rankedCandidates =
            rankCandidates(
                candidates
            )

        let isAmbiguous: Bool

        if rankedCandidates.count >= 2 {

            let first =
                rankedCandidates[0]

            let second =
                rankedCandidates[1]

            isAmbiguous =
                abs(
                    first.score.coverage -
                    second.score.coverage
                ) < 0.05 &&
                abs(
                    first.score.matchedCount -
                    second.score.matchedCount
                ) <= 1

        } else {

            isAmbiguous = false
        }

        return CTBBuildCandidateResult(
            direction:
                winner.direction,
            references:
                references,
            score:
                winner.score,
            isAmbiguous:
                isAmbiguous
        )
    }

    // MARK: - Direction Candidates

    private func makeDirectionCandidates(
        route: Route,
        localJourneyStops: [JourneyStop],
        localStopLookup: [String: Stop]
    ) async throws
        -> [CTBDirectionCandidate] {

        var candidates:
            [CTBDirectionCandidate] = []

        for direction in [
            "outbound",
            "inbound"
        ] {

            do {

                let apiRouteStops =
                    try await cache.routeStops(
                        route:
                            route.number,
                        direction:
                            direction
                    )
                    .sorted {
                        $0.sequence <
                            $1.sequence
                    }

                guard
                    !apiRouteStops.isEmpty
                else {
                    continue
                }

                var ctbStopLookup:
                    [String: CTBStopRecord] = [:]

                for routeStop in apiRouteStops {

                    if ctbStopLookup[
                        routeStop.stop
                    ] != nil {
                        continue
                    }

                    let stop =
                        try await cache.stop(
                            stopId:
                                routeStop.stop
                        )

                    ctbStopLookup[
                        routeStop.stop
                    ] = stop
                }

                let alignment =
                    sequenceAligner.align(
                        transitGoStops:
                            localJourneyStops,
                        ctbStops:
                            apiRouteStops,
                        localStopLookup:
                            localStopLookup,
                        ctbStopLookup:
                            ctbStopLookup
                    )

                let alignmentScore =
                    score(
                        alignment:
                            alignment
                    )

                candidates.append(
                    CTBDirectionCandidate(
                        direction:
                            direction,
                        alignment:
                            alignment,
                        score:
                            alignmentScore
                    )
                )

            } catch {

                print(
                    "CTB direction candidate failed",
                    "| route:",
                    route.number,
                    "| direction:",
                    direction,
                    "| error:",
                    error
                )
            }
        }

        return candidates
    }

    // MARK: - Make References

    private func makeReferences(
        from candidate:
            CTBDirectionCandidate,
        journey: Journey
    ) -> [OperatorStopReference] {

        candidate.alignment
            .matchedPairs
            .map {
                pair in

                OperatorStopReference(
                    operatorId:
                        "CTB",
                    journeyId:
                        journey.id,
                    stopId:
                        pair.transitGoStop
                            .stopId,
                    sequence:
                        pair.transitGoStop
                            .sequence,
                    operatorStopId:
                        pair.ctbStop.stop,
                    operatorServiceType:
                        "",
                    operatorDirection:
                        candidate.direction
                )
            }
            .sorted {
                $0.sequence <
                    $1.sequence
            }
    }

    // MARK: - Alignment Score

    private func score(
        alignment:
            CTBStopSequenceAlignment
    ) -> CTBAlignmentScore {

        let matchedCount =
            alignment.matchedPairs.count

        let transitGoOnlyCount =
            alignment.transitGoOnly.count

        let ctbOnlyCount =
            alignment.ctbOnly.count

        let totalHKWay =
            matchedCount +
            transitGoOnlyCount

        let coverage: Double

        if totalHKWay == 0 {

            coverage = 0

        } else {

            coverage =
                Double(matchedCount) /
                Double(totalHKWay)
        }

        let distances =
            alignment.matchedPairs.map {
                $0.distanceMeters
            }

        let averageDistance: Double

        if distances.isEmpty {

            averageDistance = 0

        } else {

            averageDistance =
                distances.reduce(
                    0,
                    +
                ) /
                Double(
                    distances.count
                )
        }

        let maximumDistance =
            distances.max() ?? 0

        return CTBAlignmentScore(
            matchedCount:
                matchedCount,
            coverage:
                coverage,
            transitGoOnlyCount:
                transitGoOnlyCount,
            ctbOnlyCount:
                ctbOnlyCount,
            averageDistance:
                averageDistance,
            maximumDistance:
                maximumDistance
        )
    }

    // MARK: - Best Candidate

    private func bestCandidate(
        from candidates:
            [CTBDirectionCandidate]
    ) -> CTBDirectionCandidate? {

        rankCandidates(
            candidates
        )
        .first
    }

    private func rankCandidates(
        _ candidates:
            [CTBDirectionCandidate]
    ) -> [CTBDirectionCandidate] {

        candidates
            .filter {
                $0.score.matchedCount > 0
            }
            .sorted {
                lhs,
                rhs in

                // 1. Prefer higher HK Way
                //    coverage.

                if lhs.score.coverage !=
                    rhs.score.coverage {

                    return lhs.score.coverage >
                        rhs.score.coverage
                }

                // 2. Prefer more matched stops.

                if lhs.score.matchedCount !=
                    rhs.score.matchedCount {

                    return lhs.score.matchedCount >
                        rhs.score.matchedCount
                }

                // 3. Prefer fewer HK Way gaps.

                if lhs.score
                    .transitGoOnlyCount !=
                    rhs.score
                    .transitGoOnlyCount {

                    return lhs.score
                        .transitGoOnlyCount <
                        rhs.score
                        .transitGoOnlyCount
                }

                // 4. Prefer fewer CTB-only gaps.

                if lhs.score.ctbOnlyCount !=
                    rhs.score.ctbOnlyCount {

                    return lhs.score
                        .ctbOnlyCount <
                        rhs.score
                        .ctbOnlyCount
                }

                // 5. Finally prefer geography.

                return lhs.score
                    .averageDistance <
                    rhs.score
                    .averageDistance
            }
    }
}


// MARK: - Full Build Result

struct CTBOperatorStopReferenceBuildResult {

    let references:
        [OperatorStopReference]

    let matchedJourneys: Int

    let unmatchedRoutes:
        [String]

    let unmatchedJourneys:
        [String]

    let ambiguousJourneys:
        [String]

    let rejectedJourneys:
        [String]
}


// MARK: - Build Candidate Result

private struct CTBBuildCandidateResult {

    let direction: String

    let references:
        [OperatorStopReference]

    let score:
        CTBAlignmentScore

    let isAmbiguous: Bool
}


// MARK: - Direction Candidate

private struct CTBDirectionCandidate {

    let direction: String

    let alignment:
        CTBStopSequenceAlignment

    let score:
        CTBAlignmentScore
}


// MARK: - Alignment Score

private struct CTBAlignmentScore {

    let matchedCount: Int

    let coverage: Double

    let transitGoOnlyCount: Int

    let ctbOnlyCount: Int

    let averageDistance: Double

    let maximumDistance: Double
}

// MARK: - CTB API Cache

private actor CTBOperatorStopReferenceCache {

    private let routeStopAPI =
        CTBRouteStopAPI()

    private let stopAPI =
        CTBStopAPI()

    private var routeStopsByKey:
        [String: [CTBRouteStopRecord]] = [:]

    private var stopsById:
        [String: CTBStopRecord] = [:]

    // MARK: - Route Stops

    func routeStops(
        route: String,
        direction: String
    ) async throws
        -> [CTBRouteStopRecord] {

        let key =
            "\(route)|\(direction)"

        if let cached =
            routeStopsByKey[key] {

            return cached
        }

        let records =
            try await routeStopAPI.fetch(
                route:
                    route,
                direction:
                    direction
            )

        routeStopsByKey[key] =
            records

        return records
    }

    // MARK: - Single Stop

    func stop(
        stopId: String
    ) async throws
        -> CTBStopRecord {

        if let cached =
            stopsById[stopId] {

            return cached
        }

        let record =
            try await stopAPI.fetch(
                stopId:
                    stopId
            )

        stopsById[stopId] =
            record

        return record
    }

    // MARK: - Prefetch Stops

    func prefetchStops(
        stopIds: Set<String>,
        concurrency: Int = 8
    ) async {

        let missingStopIds =
            stopIds.filter {
                stopsById[$0] == nil
            }

        guard
            !missingStopIds.isEmpty
        else {
            return
        }

        let ids =
            Array(missingStopIds)

        let batchSize =
            max(
                1,
                concurrency
            )

        print("")
        print("*** CTB stop prefetch ***")
        print(
            "Unique stops to fetch:",
            ids.count
        )
        print(
            "Concurrency:",
            batchSize
        )

        var completed = 0
        var failed = 0

        for startIndex in
            stride(
                from: 0,
                to: ids.count,
                by: batchSize
            ) {

            let endIndex =
                min(
                    startIndex + batchSize,
                    ids.count
                )

            let batch =
                Array(
                    ids[
                        startIndex..<endIndex
                    ]
                )

            let results =
                await withTaskGroup(
                    of:
                        CTBPrefetchedStop?.self
                ) {
                    group in

                    for stopId in batch {

                        group.addTask {

                            do {

                                let record =
                                    try await CTBStopAPI()
                                        .fetch(
                                            stopId:
                                                stopId
                                        )

                                return CTBPrefetchedStop(
                                    stopId:
                                        stopId,
                                    record:
                                        record
                                )

                            } catch {

                                print(
                                    "CTB stop fetch failed",
                                    "| stop:",
                                    stopId,
                                    "| error:",
                                    error
                                )

                                return nil
                            }
                        }
                    }

                    var batchResults:
                        [CTBPrefetchedStop] = []

                    for await result in group {

                        if let result {
                            batchResults.append(
                                result
                            )
                        }
                    }

                    return batchResults
                }

            for result in results {

                stopsById[
                    result.stopId
                ] = result.record
            }

            completed += results.count

            failed +=
                batch.count -
                results.count

            print(
                "CTB stop prefetch progress:",
                "\(completed + failed)/\(ids.count)",
                "| success:",
                completed,
                "| failed:",
                failed
            )
        }

        print("")
        print(
            "CTB stop prefetch complete",
            "| success:",
            completed,
            "| failed:",
            failed
        )
    }
}


// MARK: - Prefetched Stop

private struct CTBPrefetchedStop:
    Sendable {

    let stopId: String

    let record: CTBStopRecord
}
