//
//  KMBOperatorStopReferenceBuilder.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct KMBOperatorStopReferenceBuilder {

    private let routeAPI = KMBRouteAPI()
    private let routeStopAPI = KMBRouteStopAPI()
    private let stopAPI = KMBStopAPI()

    private let publicStopCodes =
        (try? KMBPublicStopCodeReader().read()) ?? [:]

    private let sequenceAligner =
        KMBStopSequenceAligner()

    private func operatorId(
        for route: Route
    ) -> String? {

        let supportsKMB =
            route.supportsOperator("KMB")

        let supportsLWB =
            route.supportsOperator("LWB")

        if supportsKMB && !supportsLWB {
            return "KMB"
        }

        if supportsLWB && !supportsKMB {
            return "LWB"
        }

        // Avoid guessing if a future route is
        // unexpectedly tagged as both.
        return nil
    }
    
    
    // MARK: - Full Network

    func buildAll(
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop],
    ) async throws -> KMBOperatorStopReferenceBuildResult {
        
        let kmbRoutes =
        try await routeAPI.fetchAll()
        
        let kmbStops =
        try await stopAPI.fetchAll()
        
        let kmbTransitRoutes =
            routes.filter {
                $0.supportsOperator("KMB") ||
                $0.supportsOperator("LWB")
            }
        
        for route in routes {

            print(
                "Route:",
                route.id,
                route.number,
                "| operatorIds:",
                route.operatorIds
            )
        }


        let journeyStopsByJourney =
        Dictionary(
            grouping: journeyStops,
            by: \.journeyId
        )
        
        let journeysByRoute =
        Dictionary(
            grouping: journeys,
            by: \.routeId
        )
        
        let kmbRoutesByNumber =
        Dictionary(
            grouping: kmbRoutes,
            by: \.route
        )
        
        let localStopLookup =
        Dictionary(
            uniqueKeysWithValues:
                stops.map {
                    ($0.id, $0)
                }
        )
        
        let kmbStopLookup =
        Dictionary(
            uniqueKeysWithValues:
                kmbStops.map {
                    ($0.stop, $0)
                }
        )
        
        var references:
        [OperatorStopReference] = []
        
        var unmatchedRoutes:
        [String] = []
        
        var unmatchedJourneys:
        [String] = []
        
        var uniquelyMatchedJourneys = 0
        var identicalSequenceResolvedJourneys = 0
        var coordinateResolvedJourneys = 0
        var positionResolvedJourneys = 0
        var alignmentResolvedJourneys = 0
        
        var alignmentResolvedDetails:
        [KMBAlignmentResolvedDetail] = []
        
        var rejectedAlignmentDetails:
        [KMBRejectedAlignmentDetail] = []
        
        var ambiguousJourneys:
        [KMBAmbiguousJourney] = []
        
        var noMatchingServiceJourneys:
        [KMBNoMatchingServiceJourney] = []
        
        
        // MARK: - Process Routes
        
        for route in kmbTransitRoutes {
            
            guard let operatorId =
                operatorId(for: route)
            else {
                continue
            }
            
            guard
                let apiRoutes =
                    kmbRoutesByNumber[route.number]
            else {
                
                unmatchedRoutes.append(
                    "\(route.id) | \(route.number)"
                )
                
                continue
            }
            
            let routeJourneys =
            journeysByRoute[route.id] ?? []
            
            for journey in routeJourneys {
                
                guard
                    let localStops =
                        journeyStopsByJourney[
                            journey.id
                        ]
                else {

                    unmatchedJourneys.append(
                        journey.id
                    )

                    continue
                }

                // Fetch candidates from BOTH KMB bounds.

                var allDirectionCandidates:
                    [KMBServiceCandidate] = []

                for apiRoute in apiRoutes {

                    let apiStops =
                        try await routeStopAPI.fetch(
                            route:
                                apiRoute.route,
                            direction:
                                direction(
                                    forBound:
                                        apiRoute.bound
                                ),
                            serviceType:
                                apiRoute.serviceType
                        )

                    allDirectionCandidates.append(
                        KMBServiceCandidate(
                            bound:
                                apiRoute.bound,
                            serviceType:
                                apiRoute.serviceType,
                            stops:
                                apiStops
                        )
                    )
                }

                // Score each candidate using the physical
                // first + last stop of the HK Way journey.

                let boundScores =
                    allDirectionCandidates.compactMap {
                        candidate
                        -> (candidate: KMBServiceCandidate,
                            score: Double)? in

                        guard let score =
                            endpointScore(
                                candidate:
                                    candidate,
                                localJourneyStops:
                                    localStops,
                                localStopLookup:
                                    localStopLookup,
                                kmbStopLookup:
                                    kmbStopLookup
                            )
                        else {
                            return nil
                        }

                        return (
                            candidate:
                                candidate,
                            score:
                                score
                        )
                    }
                    .sorted {
                        $0.score <
                            $1.score
                    }

                guard let bestBound =
                    boundScores.first?
                        .candidate
                        .bound
                else {

                    unmatchedJourneys.append(
                        journey.id
                    )

                    continue
                }

                // From this point onward, keep the existing
                // service-selection logic restricted to the
                // physically matched KMB bound.

                let matchingAPIRoutes =
                    apiRoutes.filter {
                        $0.bound == bestBound
                    }

                guard
                    !matchingAPIRoutes.isEmpty
                else {

                    unmatchedJourneys.append(
                        journey.id
                    )

                    continue
                }
                
                guard
                    !matchingAPIRoutes.isEmpty
                else {
                    
                    unmatchedJourneys.append(
                        journey.id
                    )
                    
                    continue
                }
                
                guard
                    let localStops =
                        journeyStopsByJourney[
                            journey.id
                        ]
                else {
                    
                    unmatchedJourneys.append(
                        journey.id
                    )
                    
                    continue
                }
                
                // Fetch all KMB service variants
                // for this route + bound.
                
                var allCandidates:
                [KMBServiceCandidate] = []
                
                for apiRoute in matchingAPIRoutes {
                    
                    let apiStops =
                    try await routeStopAPI.fetch(
                        route:
                            apiRoute.route,
                        direction:
                            direction(
                                forBound:
                                    apiRoute.bound
                            ),
                        serviceType:
                            apiRoute.serviceType
                    )
                    
                    allCandidates.append(
                        KMBServiceCandidate(
                            bound:
                                apiRoute.bound,
                            serviceType:
                                apiRoute.serviceType,
                            stops:
                                apiStops
                        )
                    )
                }
                
                // MARK: - Exact Count Candidates
                
                let candidates =
                allCandidates.filter {
                    $0.stops.count ==
                    localStops.count
                }
                
                var selectedCandidate:
                KMBServiceCandidate?
                
                // References created through alignment
                // are already sequence-mapped, so they
                // are handled separately.
                
                var alignedReferences:
                [OperatorStopReference]?
                
                // MARK: 1. No Exact Count Candidate
                
                if candidates.isEmpty {
                    
                    let alignmentCandidates =
                    allCandidates.compactMap {
                        candidate
                        -> KMBAlignmentCandidate?
                        in
                        
                        let alignment =
                        sequenceAligner.align(
                            transitGoStops:
                                localStops,
                            kmbStops:
                                candidate.stops,
                            localStopLookup:
                                localStopLookup,
                            kmbStopLookup:
                                kmbStopLookup
                        )
                        
                        guard
                            let score =
                                alignmentScore(
                                    alignment:
                                        alignment,
                                    localCount:
                                        localStops.count,
                                    kmbCount:
                                        candidate.stops.count
                                )
                        else {
                            return nil
                        }
                        
                        return KMBAlignmentCandidate(
                            candidate:
                                candidate,
                            alignment:
                                alignment,
                            score:
                                score
                        )
                    }
                    .sorted {
                        $0.score.averageDistance <
                            $1.score.averageDistance
                    }
                    
                    // Only accept if exactly one
                    // alignment is clearly acceptable.
                    //
                    // If multiple KMB services produce
                    // acceptable alignments, don't guess.
                    
                    let acceptable =
                    alignmentCandidates.filter {
                        isAcceptableAlignment(
                            $0.score
                        )
                    }

                    let bestRejectedAlignment =
                    alignmentCandidates.first

                    if let winner =
                        bestAcceptableAlignment(acceptable) {

                        alignedReferences =
                            makeAlignedReferences(
                                journey: journey,
                                alignment: winner.alignment,
                                kmbStopLookup:
                                    kmbStopLookup,
                                serviceType:
                                    winner.candidate.serviceType,
                                operatorId:
                                    operatorId,
                                operatorDirection:
                                    winner.candidate.bound
                            )

                        alignmentResolvedJourneys += 1

                        alignmentResolvedDetails.append(
                            KMBAlignmentResolvedDetail(
                                routeId: route.id,
                                routeNumber: route.number,
                                journeyId: journey.id,
                                bound: bestBound,
                                serviceType:
                                    winner.candidate.serviceType,
                                matchedCount:
                                    winner.score.matchedCount,
                                transitGoOnlyCount:
                                    winner.score.transitGoOnlyCount,
                                kmbOnlyCount:
                                    winner.score.kmbOnlyCount,
                                coverage:
                                    winner.score.coverage,
                                averageDistance:
                                    winner.score.averageDistance,
                                maximumDistance:
                                    winner.score.maximumDistance
                            )
                        )

                    } else {

                        if let rejected =
                            bestRejectedAlignment {

                            rejectedAlignmentDetails.append(
                                KMBRejectedAlignmentDetail(
                                    routeId: route.id,
                                    routeNumber: route.number,
                                    journeyId: journey.id,
                                    bound: bestBound,
                                    serviceType:
                                        rejected.candidate.serviceType,
                                    transitGoCount:
                                        localStops.count,
                                    kmbCount:
                                        rejected.candidate.stops.count,
                                    matchedCount:
                                        rejected.score.matchedCount,
                                    transitGoOnlyCount:
                                        rejected.score.transitGoOnlyCount,
                                    kmbOnlyCount:
                                        rejected.score.kmbOnlyCount,
                                    coverage:
                                        rejected.score.coverage,
                                    averageDistance:
                                        rejected.score.averageDistance,
                                    maximumDistance:
                                        rejected.score.maximumDistance
                                )
                            )
                        }

                        noMatchingServiceJourneys.append(
                            KMBNoMatchingServiceJourney(
                                routeId: route.id,
                                routeNumber: route.number,
                                journeyId: journey.id,
                                bound: bestBound,
                                transitGoCount:
                                    localStops.count
                            )
                        )

                        continue
                    }

                    } else if candidates.count == 1 {
                        
                        selectedCandidate =
                        candidates[0]
                        
                        uniquelyMatchedJourneys += 1
                        
                    } else {
                        
                        // MARK: - Multiple Exact Candidates
                        
                        let identicalSequences =
                        haveIdenticalStopSequences(
                            candidates
                        )
                        
                        let positionWins =
                        positionWinCounts(
                            localJourneyStops:
                                localStops,
                            candidates:
                                candidates,
                            localStopLookup:
                                localStopLookup,
                            kmbStopLookup:
                                kmbStopLookup
                        )
                        
                        let scoredCandidates =
                        candidates.compactMap {
                            candidate
                            -> KMBScoredServiceCandidate?
                            in
                            
                            guard
                                let score =
                                    coordinateScore(
                                        localJourneyStops:
                                            localStops,
                                        apiStops:
                                            candidate.stops,
                                        localStopLookup:
                                            localStopLookup,
                                        kmbStopLookup:
                                            kmbStopLookup
                                    )
                            else {
                                return nil
                            }
                            
                            return KMBScoredServiceCandidate(
                                candidate:
                                    candidate,
                                averageDistance:
                                    score
                            )
                        }
                        .sorted {
                            $0.averageDistance <
                                $1.averageDistance
                        }
                        
                        // MARK: 3. Identical Sequence
                        
                        if identicalSequences {
                            
                            selectedCandidate =
                            candidates[0]
                            
                            identicalSequenceResolvedJourneys += 1
                            
                            // MARK: 4. Coordinate Resolver
                            
                        } else if
                            let winner =
                                coordinateWinner(
                                    from:
                                        scoredCandidates
                                ) {
                            
                            selectedCandidate =
                            winner
                            
                            coordinateResolvedJourneys += 1
                            
                            // MARK: 5. Position Resolver
                            
                        } else if
                            let winner =
                                positionWinner(
                                    candidates:
                                        candidates,
                                    positionWins:
                                        positionWins
                                ) {
                            
                            selectedCandidate =
                            winner
                            
                            positionResolvedJourneys += 1
                            
                            // MARK: 6. Still Ambiguous
                            
                        } else {
                            
                            ambiguousJourneys.append(
                                makeAmbiguousJourney(
                                    route:
                                        route,
                                    journey:
                                        journey,
                                    bound:
                                        bestBound,
                                    localStopCount:
                                        localStops.count,
                                    identicalSequences:
                                        identicalSequences,
                                    candidates:
                                        candidates,
                                    scoredCandidates:
                                        scoredCandidates,
                                    positionWins:
                                        positionWins
                                )
                            )
                            
                            continue
                        }
                    }
                    
                    // MARK: - Alignment References
                    
                    if let alignedReferences {
                        
                        references.append(
                            contentsOf:
                                alignedReferences
                        )
                        
                        continue
                    }
                    
                    // MARK: - Exact Sequence References
                    
                    guard
                        let candidate =
                            selectedCandidate
                    else {
                        continue
                    }
                    
                    let localBySequence =
                    Dictionary(
                        uniqueKeysWithValues:
                            localStops.map {
                                ($0.sequence, $0)
                            }
                    )
                    
                    var journeyReferences:
                    [OperatorStopReference] = []
                    
                    var sequenceMismatch =
                    false
                    
                    for apiStop in candidate.stops {
                        
                        guard
                            let sequence =
                                apiStop.sequence,
                            
                                let localStop =
                                localBySequence[
                                    sequence
                                ]
                        else {
                            
                            sequenceMismatch =
                            true
                            
                            break
                        }
                        
                        let operatorStop =
                            kmbStopLookup[apiStop.stop]

                        journeyReferences.append(
                            OperatorStopReference(
                                operatorId:
                                    operatorId,
                                journeyId:
                                    journey.id,
                                stopId:
                                    localStop.stopId,
                                sequence:
                                    localStop.sequence,
                                operatorStopId:
                                    apiStop.stop,
                                publicStopCode:
                                    publicStopCodes[
                                        apiStop.stop.uppercased()
                                    ],
                                operatorLatitude:
                                    operatorStop?
                                        .latitudeValue,
                                operatorLongitude:
                                    operatorStop?
                                        .longitudeValue,
                                operatorServiceType:
                                    candidate.serviceType,
                                operatorDirection:
                                    candidate.bound
                            )
                        )
                    }
                    
                    if sequenceMismatch {
                        
                        unmatchedJourneys.append(
                            "\(journey.id) | sequence mismatch"
                        )
                        
                        continue
                    }
                    
                    references.append(
                        contentsOf:
                            journeyReferences
                    )
                }
            }
            
            // MARK: - Result
            
            return KMBOperatorStopReferenceBuildResult(
                references: references,
                
                uniquelyMatchedJourneys:
                    uniquelyMatchedJourneys,
                
                identicalSequenceResolvedJourneys:
                    identicalSequenceResolvedJourneys,
                
                coordinateResolvedJourneys:
                    coordinateResolvedJourneys,
                
                positionResolvedJourneys:
                    positionResolvedJourneys,
                
                alignmentResolvedJourneys:
                    alignmentResolvedJourneys,
                
                alignmentResolvedDetails:
                    alignmentResolvedDetails,
                
                rejectedAlignmentDetails:
                    rejectedAlignmentDetails,
                
                unmatchedRoutes:
                    unmatchedRoutes.sorted(),
                
                unmatchedJourneys:
                    unmatchedJourneys,
                
                ambiguousJourneys:
                    ambiguousJourneys,
                
                noMatchingServiceJourneys:
                    noMatchingServiceJourneys
            )
        }
        
        // MARK: - Single Route
        
        func build(
            operatorId: String = "KMB",
            routeNumber: String,
            direction: String,
            serviceType: String,
            journeyStops: [JourneyStop]
        ) async throws -> [OperatorStopReference] {
            
            let apiRecords =
            try await routeStopAPI.fetch(
                route:
                    routeNumber,
                direction:
                    direction,
                serviceType:
                    serviceType
            )
            
            let journeyStopsBySequence =
            Dictionary(
                uniqueKeysWithValues:
                    journeyStops.map {
                        ($0.sequence, $0)
                    }
            )
            
            var references:
            [OperatorStopReference] = []
            
            for apiRecord in apiRecords {
                
                guard
                    let sequence =
                        apiRecord.sequence
                else {
                    
                    throw
                    KMBOperatorStopReferenceBuilderError
                        .invalidSequence(
                            apiRecord.seq
                        )
                }
                
                guard
                    let journeyStop =
                        journeyStopsBySequence[
                            sequence
                        ]
                else {
                    
                    throw
                    KMBOperatorStopReferenceBuilderError
                        .missingJourneyStop(
                            route:
                                routeNumber,
                            sequence:
                                sequence
                        )
                }
                
                references.append(
                    OperatorStopReference(
                        operatorId:
                            operatorId,
                        journeyId:
                            journeyStop.journeyId,
                        stopId:
                            journeyStop.stopId,
                        sequence:
                            journeyStop.sequence,
                        operatorStopId:
                            apiRecord.stop,
                        publicStopCode:
                            publicStopCodes[
                                apiRecord.stop.uppercased()
                            ],
                        operatorServiceType:
                            serviceType,
                        operatorDirection:
                            direction == "inbound"
                            ? "I"
                            : "O"
                    )
                )
            }
            
            return references.sorted {
                $0.sequence < $1.sequence
            }
        }
        
        // MARK: - Alignment Scoring
        
        private func alignmentScore(
            alignment: KMBStopSequenceAlignment,
            localCount: Int,
            kmbCount: Int
        ) -> KMBAlignmentScore? {
            
            guard
                !alignment.matchedPairs.isEmpty
            else {
                return nil
            }
            
            let matched =
            alignment.matchedPairs.count
            
            let denominator =
            max(localCount, kmbCount)
            
            guard denominator > 0 else {
                return nil
            }
            
            let coverage =
            Double(matched) /
            Double(denominator)
            
            let totalGaps =
            alignment.transitGoOnly.count +
            alignment.kmbOnly.count
            
            let totalDistance =
            alignment.matchedPairs.reduce(
                0.0
            ) {
                $0 + $1.distanceMeters
            }
            
            let averageDistance =
            totalDistance /
            Double(matched)
            
            let maximumDistance =
            alignment.matchedPairs
                .map {
                    $0.distanceMeters
                }
                .max() ?? 0
            
            return KMBAlignmentScore(
                matchedCount:
                    matched,
                coverage:
                    coverage,
                totalGaps:
                    totalGaps,
                transitGoOnlyCount:
                    alignment.transitGoOnly.count,
                kmbOnlyCount:
                    alignment.kmbOnly.count,
                averageDistance:
                    averageDistance,
                maximumDistance:
                    maximumDistance
            )
        }
    

        private func isAcceptableAlignment(
            _ score: KMBAlignmentScore
        ) -> Bool {

            // Tier 1:
            // Very small sequence difference.

            if score.coverage >= 0.90 &&
                score.totalGaps <= 2 {

                return true
            }

            // Tier 2:
            // Allow up to 3 gaps, but require
            // strong geographic agreement.

            if score.coverage >= 0.90 &&
                score.totalGaps <= 3 &&
                score.averageDistance <= 400 &&
                score.maximumDistance <= 700 {

                return true
            }

            return false
        }
    
    // MARK: - Best Acceptable Alignment

    private func bestAcceptableAlignment(
        _ candidates: [KMBAlignmentCandidate]
    ) -> KMBAlignmentCandidate? {

        guard !candidates.isEmpty else {
            return nil
        }

        let sorted = candidates.sorted { lhs, rhs in

            // 1. Prefer fewer sequence gaps.
            if lhs.score.totalGaps != rhs.score.totalGaps {
                return lhs.score.totalGaps < rhs.score.totalGaps
            }

            // 2. Prefer higher coverage.
            if lhs.score.coverage != rhs.score.coverage {
                return lhs.score.coverage > rhs.score.coverage
            }

            // 3. Prefer lower average geographic distance.
            return lhs.score.averageDistance <
                rhs.score.averageDistance
        }

        guard let best = sorted.first else {
            return nil
        }

        // One acceptable candidate is already decisive.
        guard sorted.count > 1 else {
            return best
        }

        let second = sorted[1]

        // Fewer gaps is a strong win.
        if best.score.totalGaps <
            second.score.totalGaps {

            return best
        }

        // Same gaps: require meaningfully better coverage.
        if best.score.totalGaps ==
            second.score.totalGaps {

            let coverageAdvantage =
                best.score.coverage -
                second.score.coverage

            if coverageAdvantage >= 0.02 {
                return best
            }

            // Same/nearly-same coverage:
            // require a meaningful distance advantage.

            if abs(coverageAdvantage) < 0.001 {

                let distanceRatio =
                    best.score.averageDistance /
                    second.score.averageDistance

                if distanceRatio <= 0.95 {
                    return best
                }
            }
        }

        return nil
    }

    // MARK: - Alignment References

    private func makeAlignedReferences(
        journey: Journey,
        alignment: KMBStopSequenceAlignment,
        kmbStopLookup: [String: KMBStopRecord],
        serviceType: String,
        operatorId: String,
        operatorDirection: String
    ) -> [OperatorStopReference] {

        alignment.matchedPairs
            .map {
                pair in

                let operatorStop =
                    kmbStopLookup[pair.kmbStop.stop]

                return OperatorStopReference(
                    operatorId:
                        operatorId,
                    journeyId:
                        journey.id,
                    stopId:
                        pair.transitGoStop.stopId,
                    sequence:
                        pair.transitGoStop.sequence,
                    operatorStopId:
                        pair.kmbStop.stop,
                    publicStopCode:
                        publicStopCodes[
                            pair.kmbStop.stop.uppercased()
                        ],
                    operatorLatitude:
                        operatorStop?.latitudeValue,
                    operatorLongitude:
                        operatorStop?.longitudeValue,
                    operatorServiceType:
                        serviceType,
                    operatorDirection:
                        operatorDirection
                )
            }
            .sorted {
                $0.sequence < $1.sequence
            }
    }

    // MARK: - Coordinate Winner

    private func coordinateWinner(
        from scoredCandidates:
            [KMBScoredServiceCandidate]
    ) -> KMBServiceCandidate? {

        guard
            scoredCandidates.count >= 2
        else {
            return nil
        }

        let best =
            scoredCandidates[0]

        let second =
            scoredCandidates[1]

        guard
            second.averageDistance > 0
        else {
            return nil
        }

        let ratio =
            best.averageDistance /
            second.averageDistance

        guard ratio < 0.75 else {
            return nil
        }

        return best.candidate
    }

    // MARK: - Position Winner

    private func positionWinner(
        candidates:
            [KMBServiceCandidate],
        positionWins:
            [String: Int]
    ) -> KMBServiceCandidate? {

        let ranked =
            candidates
                .map {
                    candidate in

                    (
                        candidate:
                            candidate,

                        wins:
                            positionWins[
                                candidate.serviceType
                            ] ?? 0
                    )
                }
                .sorted {
                    $0.wins > $1.wins
                }

        guard
            ranked.count >= 2
        else {
            return nil
        }

        let best =
            ranked[0]

        let second =
            ranked[1]

        let totalDecisiveWins =
            ranked.reduce(0) {
                $0 + $1.wins
            }

        guard
            best.wins >= 3
        else {
            return nil
        }

        guard
            best.wins -
                second.wins >= 2
        else {
            return nil
        }

        guard
            totalDecisiveWins > 0
        else {
            return nil
        }

        let winRatio =
            Double(best.wins) /
            Double(totalDecisiveWins)

        guard
            winRatio >= 0.75
        else {
            return nil
        }

        return best.candidate
    }

    // MARK: - Ambiguous Diagnostic

    private func makeAmbiguousJourney(
        route: Route,
        journey: Journey,
        bound: String,
        localStopCount: Int,
        identicalSequences: Bool,
        candidates:
            [KMBServiceCandidate],
        scoredCandidates:
            [KMBScoredServiceCandidate],
        positionWins:
            [String: Int]
    ) -> KMBAmbiguousJourney {

        let scoreLookup =
            Dictionary(
                uniqueKeysWithValues:
                    scoredCandidates.map {
                        (
                            $0.candidate
                                .serviceType,
                            $0.averageDistance
                        )
                    }
            )

        let diagnosticCandidates =
            candidates
                .map {
                    candidate in

                    KMBAmbiguousCandidate(
                        serviceType:
                            candidate.serviceType,

                        averageDistance:
                            scoreLookup[
                                candidate
                                    .serviceType
                            ] ?? .infinity,

                        positionWins:
                            positionWins[
                                candidate
                                    .serviceType
                            ] ?? 0
                    )
                }
                .sorted {
                    $0.averageDistance <
                        $1.averageDistance
                }

        return KMBAmbiguousJourney(
            routeId:
                route.id,
            routeNumber:
                route.number,
            journeyId:
                journey.id,
            bound:
                bound,
            transitGoCount:
                localStopCount,
            identicalStopSequences:
                identicalSequences,
            candidates:
                diagnosticCandidates
        )
    }

    // MARK: - Coordinate Scoring

    private func coordinateScore(
        localJourneyStops:
            [JourneyStop],
        apiStops:
            [KMBRouteStopRecord],
        localStopLookup:
            [String: Stop],
        kmbStopLookup:
            [String: KMBStopRecord]
    ) -> Double? {

        let localBySequence =
            Dictionary(
                uniqueKeysWithValues:
                    localJourneyStops.map {
                        ($0.sequence, $0)
                    }
            )

        var distances:
            [Double] = []

        for apiStop in apiStops {

            guard
                let sequence =
                    apiStop.sequence,

                let localJourneyStop =
                    localBySequence[
                        sequence
                    ],

                let localStop =
                    localStopLookup[
                        localJourneyStop.stopId
                    ],

                let kmbStop =
                    kmbStopLookup[
                        apiStop.stop
                    ],

                let kmbLatitude =
                    kmbStop.latitudeValue,

                let kmbLongitude =
                    kmbStop.longitudeValue
            else {
                continue
            }

            let distance =
                distanceMeters(
                    latitude1:
                        localStop.latitude,
                    longitude1:
                        localStop.longitude,
                    latitude2:
                        kmbLatitude,
                    longitude2:
                        kmbLongitude
                )

            distances.append(
                distance
            )
        }

        guard
            !distances.isEmpty
        else {
            return nil
        }

        return distances.reduce(0, +) /
            Double(distances.count)
    }

    // MARK: - Position Wins

    private func positionWinCounts(
        localJourneyStops:
            [JourneyStop],
        candidates:
            [KMBServiceCandidate],
        localStopLookup:
            [String: Stop],
        kmbStopLookup:
            [String: KMBStopRecord]
    ) -> [String: Int] {

        let localBySequence =
            Dictionary(
                uniqueKeysWithValues:
                    localJourneyStops.map {
                        ($0.sequence, $0)
                    }
            )

        var wins:
            [String: Int] = [:]

        for candidate in candidates {

            wins[
                candidate.serviceType
            ] = 0
        }

        let sequences =
            localBySequence.keys.sorted()

        for sequence in sequences {

            guard
                let journeyStop =
                    localBySequence[
                        sequence
                    ],

                let localStop =
                    localStopLookup[
                        journeyStop.stopId
                    ]
            else {
                continue
            }

            var distances:
                [(String, Double)] = []

            for candidate in candidates {

                guard
                    let apiStop =
                        candidate.stops.first(
                            where: {
                                $0.sequence ==
                                    sequence
                            }
                        ),

                    let kmbStop =
                        kmbStopLookup[
                            apiStop.stop
                        ],

                    let latitude =
                        kmbStop.latitudeValue,

                    let longitude =
                        kmbStop.longitudeValue
                else {
                    continue
                }

                let distance =
                    distanceMeters(
                        latitude1:
                            localStop.latitude,
                        longitude1:
                            localStop.longitude,
                        latitude2:
                            latitude,
                        longitude2:
                            longitude
                    )

                distances.append(
                    (
                        candidate.serviceType,
                        distance
                    )
                )
            }

            guard
                distances.count >= 2
            else {
                continue
            }

            let sorted =
                distances.sorted {
                    $0.1 < $1.1
                }

            let best =
                sorted[0]

            let second =
                sorted[1]

            guard
                abs(
                    best.1 -
                    second.1
                ) > 5
            else {
                continue
            }

            wins[
                best.0,
                default: 0
            ] += 1
        }

        return wins
    }

    // MARK: - Identical Stop Sequences

    private func haveIdenticalStopSequences(
        _ candidates:
            [KMBServiceCandidate]
    ) -> Bool {

        guard
            let first =
                candidates.first
        else {
            return false
        }

        let firstStops =
            first.stops
                .sorted {
                    ($0.sequence ?? 0) <
                        ($1.sequence ?? 0)
                }
                .map {
                    $0.stop
                }

        for candidate in
            candidates.dropFirst() {

            let candidateStops =
                candidate.stops
                    .sorted {
                        ($0.sequence ?? 0) <
                            ($1.sequence ?? 0)
                    }
                    .map {
                        $0.stop
                    }

            if candidateStops !=
                firstStops {

                return false
            }
        }

        return true
    }

    // MARK: - Distance

    private func distanceMeters(
        latitude1: Double,
        longitude1: Double,
        latitude2: Double,
        longitude2: Double
    ) -> Double {

        let earthRadius =
            6_371_000.0

        let lat1 =
            latitude1 *
            .pi / 180

        let lat2 =
            latitude2 *
            .pi / 180

        let deltaLat =
            (latitude2 - latitude1) *
            .pi / 180

        let deltaLon =
            (longitude2 - longitude1) *
            .pi / 180

        let a =
            sin(deltaLat / 2) *
            sin(deltaLat / 2) +
            cos(lat1) *
            cos(lat2) *
            sin(deltaLon / 2) *
            sin(deltaLon / 2)

        let c =
            2 * atan2(
                sqrt(a),
                sqrt(1 - a)
            )

        return earthRadius * c
    }

    // MARK: - Bound Resolution

    private func endpointScore(
        candidate: KMBServiceCandidate,
        localJourneyStops: [JourneyStop],
        localStopLookup: [String: Stop],
        kmbStopLookup: [String: KMBStopRecord]
    ) -> Double? {

        let localStops =
            localJourneyStops.sorted {
                $0.sequence < $1.sequence
            }

        let apiStops =
            candidate.stops.sorted {
                ($0.sequence ?? 0) <
                    ($1.sequence ?? 0)
            }

        guard
            let localFirstJourneyStop =
                localStops.first,
            let localLastJourneyStop =
                localStops.last,
            let apiFirstStop =
                apiStops.first,
            let apiLastStop =
                apiStops.last,

            let localFirstStop =
                localStopLookup[
                    localFirstJourneyStop.stopId
                ],
            let localLastStop =
                localStopLookup[
                    localLastJourneyStop.stopId
                ],

            let kmbFirstStop =
                kmbStopLookup[
                    apiFirstStop.stop
                ],
            let kmbLastStop =
                kmbStopLookup[
                    apiLastStop.stop
                ],

            let kmbFirstLatitude =
                kmbFirstStop.latitudeValue,
            let kmbFirstLongitude =
                kmbFirstStop.longitudeValue,
            let kmbLastLatitude =
                kmbLastStop.latitudeValue,
            let kmbLastLongitude =
                kmbLastStop.longitudeValue
        else {
            return nil
        }

        let firstDistance =
            distanceMeters(
                latitude1:
                    localFirstStop.latitude,
                longitude1:
                    localFirstStop.longitude,
                latitude2:
                    kmbFirstLatitude,
                longitude2:
                    kmbFirstLongitude
            )

        let lastDistance =
            distanceMeters(
                latitude1:
                    localLastStop.latitude,
                longitude1:
                    localLastStop.longitude,
                latitude2:
                    kmbLastLatitude,
                longitude2:
                    kmbLastLongitude
            )

        return firstDistance +
            lastDistance
    }

    // MARK: - Direction Mapping
    private func bound(
        for journey: Journey
    ) -> String? {

        switch journey.direction {

        case "1":
            return "O"

        case "2":
            return "I"

        default:
            return nil
        }
    }

    private func direction(
        forBound bound: String
    ) -> String {

        switch bound {

        case "I":
            return "inbound"

        default:
            return "outbound"
        }
    }
}


// MARK: - Internal Candidates

private struct KMBServiceCandidate {

    let bound: String
    let serviceType: String
    let stops: [KMBRouteStopRecord]
}

private struct KMBScoredServiceCandidate {

    let candidate:
        KMBServiceCandidate

    let averageDistance:
        Double
}


// MARK: - Alignment Candidate

private struct KMBAlignmentCandidate {

    let candidate:
        KMBServiceCandidate

    let alignment:
        KMBStopSequenceAlignment

    let score:
        KMBAlignmentScore
}

private struct KMBAlignmentScore {

    let matchedCount: Int

    let coverage: Double

    let totalGaps: Int

    let transitGoOnlyCount: Int

    let kmbOnlyCount: Int

    let averageDistance: Double

    let maximumDistance: Double
}

// MARK: - Build Result

struct KMBOperatorStopReferenceBuildResult {

    let references:
        [OperatorStopReference]

    let uniquelyMatchedJourneys:
        Int

    let identicalSequenceResolvedJourneys:
        Int

    let coordinateResolvedJourneys:
        Int

    let positionResolvedJourneys:
        Int

    let alignmentResolvedJourneys:
        Int

    let alignmentResolvedDetails:
        [KMBAlignmentResolvedDetail]

    let rejectedAlignmentDetails:
        [KMBRejectedAlignmentDetail]
    
    let unmatchedRoutes:
        [String]

    let unmatchedJourneys:
        [String]

    let ambiguousJourneys:
        [KMBAmbiguousJourney]

    let noMatchingServiceJourneys:
        [KMBNoMatchingServiceJourney]
}


// MARK: - Ambiguous Journey

struct KMBAmbiguousJourney {

    let routeId: String
    let routeNumber: String
    let journeyId: String

    let bound: String
    let transitGoCount: Int

    let identicalStopSequences: Bool

    let candidates:
        [KMBAmbiguousCandidate]
}

struct KMBAmbiguousCandidate {

    let serviceType: String
    let averageDistance: Double
    let positionWins: Int
}


// MARK: - No Matching Service

struct KMBNoMatchingServiceJourney {

    let routeId: String
    let routeNumber: String
    let journeyId: String

    let bound: String
    let transitGoCount: Int
}

struct KMBAlignmentResolvedDetail {

    let routeId: String
    let routeNumber: String
    let journeyId: String

    let bound: String
    let serviceType: String

    let matchedCount: Int

    let transitGoOnlyCount: Int
    let kmbOnlyCount: Int

    let coverage: Double

    let averageDistance: Double
    let maximumDistance: Double
}

struct KMBRejectedAlignmentDetail {

    let routeId: String
    let routeNumber: String
    let journeyId: String

    let bound: String
    let serviceType: String

    let transitGoCount: Int
    let kmbCount: Int

    let matchedCount: Int

    let transitGoOnlyCount: Int
    let kmbOnlyCount: Int

    let coverage: Double

    let averageDistance: Double
    let maximumDistance: Double
}

// MARK: - Errors

enum KMBOperatorStopReferenceBuilderError:
    Error {

    case invalidSequence(String)

    case missingJourneyStop(
        route: String,
        sequence: Int
    )
}
