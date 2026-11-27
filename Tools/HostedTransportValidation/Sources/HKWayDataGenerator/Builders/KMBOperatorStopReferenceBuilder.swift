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

    // The per-service reader is available only by explicit selection for equivalence checks.
    enum RouteStopSource {
        case bulk, perServiceReference
    }

    func buildAll(
        routes: [Route],
        journeys: [Journey],
        journeyStops: [JourneyStop],
        stops: [Stop],
        source: RouteStopSource = .bulk
    ) async throws -> KMBOperatorStopReferenceBuildResult {
        let metrics = KMBTiming.RequestCounts()
        let start = ProcessInfo.processInfo.systemUptime
        defer { metrics.report(elapsed: ProcessInfo.processInfo.systemUptime - start) }
        return try await KMBTiming.$counts.withValue(metrics) {
            async let routeList = routeAPI.fetchAll()
            async let stopList = stopAPI.fetchAll()
            async let routeStopList = source == .bulk ? routeStopAPI.fetchAll() : []
            let (kmbRoutes, kmbStops, bulkRecords) = try await (routeList, stopList, routeStopList)
            return try await buildFromSources(
                routes: routes, journeys: journeys, journeyStops: journeyStops, stops: stops,
                kmbRoutes: kmbRoutes, kmbStops: kmbStops,
                bulkRecords: source == .bulk ? bulkRecords : nil
            ) { key in
                try await routeStopAPI.fetch(route: key.route, direction: key.apiDirection, serviceType: key.serviceType)
            }
        }
    }

    func buildFromSources(
        routes: [Route], journeys: [Journey], journeyStops: [JourneyStop], stops: [Stop],
        kmbRoutes: [KMBRouteRecord], kmbStops: [KMBStopRecord], bulkRecords: [KMBRouteStopRecord]?,
        referenceLookup: @Sendable (KMBServiceKey) async throws -> [KMBRouteStopRecord]
    ) async throws -> KMBOperatorStopReferenceBuildResult {
        let (knownStops, bulkIndex) = try KMBTiming.measure("KMB catalogue validation and indexing") {
            let expected = Set(try kmbRoutes.map {
                try KMBServiceKey(route: $0.route, bound: $0.bound, serviceType: $0.serviceType)
            })
            var knownStops = Set<String>()
            for stop in kmbStops {
                guard !stop.stop.isEmpty else { throw KMBRouteStopIntegrityError.emptyCatalogue }
                guard knownStops.insert(stop.stop).inserted else {
                    throw KMBRouteStopIntegrityError.duplicateStop(stop.stop)
                }
            }
            guard !expected.isEmpty, !knownStops.isEmpty else { throw KMBRouteStopIntegrityError.emptyCatalogue }
            let index = try bulkRecords.map {
                try KMBRouteStopIndex(records: $0, expected: expected, knownStops: knownStops)
            }
            print("KMB catalogue: route rows=\(kmbRoutes.count) services=\(expected.count) stops=\(knownStops.count) bulk stop rows=\(bulkRecords?.count ?? 0)")
            return (knownStops, index)
        }

        var referenceCache: [KMBServiceKey: [KMBRouteStopRecord]] = [:]
        var lookupTime: TimeInterval = 0
        func routeStops(_ route: KMBRouteRecord) async throws -> [KMBRouteStopRecord] {
            let key = try KMBServiceKey(route: route.route, bound: route.bound, serviceType: route.serviceType)
            if let bulkIndex { return try bulkIndex.records(for: key) }
            if let records = referenceCache[key] { return records }
            let start = ProcessInfo.processInfo.systemUptime
            defer { lookupTime += ProcessInfo.processInfo.systemUptime - start }
            let received = try await referenceLookup(key)
            let records = try KMBRouteStopIndex(records: received, expected: [key], knownStops: knownStops)
                .records(for: key)
            referenceCache[key] = records
            return records
        }

        let matchingStart = ProcessInfo.processInfo.systemUptime
        defer {
            let elapsed = ProcessInfo.processInfo.systemUptime - matchingStart
            print("KMB TD matching and alignment elapsed=\(elapsed - lookupTime)s reference lookup=\(lookupTime)s")
        }

        let kmbTransitRoutes =
            routes.filter {
                $0.supportsOperator("KMB") ||
                $0.supportsOperator("LWB")
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

                let orderedRoutes = apiRoutes.sorted {
                    ($0.bound, $0.serviceType) < ($1.bound, $1.serviceType)
                }
                var candidates: [KMBServiceCandidate] = []
                for apiRoute in orderedRoutes {
                    candidates.append(KMBServiceCandidate(bound: apiRoute.bound, serviceType: apiRoute.serviceType,
                                                          stops: try await routeStops(apiRoute)))
                }

                // Keep physical endpoint evidence for selecting the bound. Exact
                // cross-bound ties cannot establish direction, especially for loops.
                let boundScores = candidates.compactMap { candidate in
                    endpointScore(candidate: candidate, localJourneyStops: localStops,
                                  localStopLookup: localStopLookup, kmbStopLookup: kmbStopLookup)
                        .flatMap { $0.isFinite ? (candidate: candidate, score: $0) : nil }
                }
                guard let endpointMinimum = boundScores.map(\.score).min() else {
                    unmatchedJourneys.append(journey.id)
                    continue
                }
                let bestEndpoints = boundScores.filter { $0.score == endpointMinimum }
                let bounds = Set(bestEndpoints.map { $0.candidate.bound })
                guard bounds.count == 1, let bestBound = bounds.first else {
                    ambiguousJourneys.append(KMBAmbiguousJourney(
                        routeId: route.id, routeNumber: route.number, journeyId: journey.id,
                        bound: bounds.sorted().joined(separator: "/"), transitGoCount: localStops.count,
                        reason: .tiedDirectionEndpoints,
                        identicalStopSequences: haveIdenticalStopSequences(bestEndpoints.map(\.candidate)),
                        candidates: bestEndpoints.map {
                            KMBAmbiguousCandidate(serviceType: $0.candidate.serviceType, averageDistance: $0.score / 2)
                        }
                    ))
                    continue
                }

                // Stop counts are not identity evidence. Every service in the
                // selected bound must pass ordered, position-level alignment.
                let alignments = candidates.filter { $0.bound == bestBound }.compactMap { candidate -> KMBAlignmentCandidate? in
                    let alignment = sequenceAligner.align(transitGoStops: localStops, kmbStops: candidate.stops,
                                                          localStopLookup: localStopLookup, kmbStopLookup: kmbStopLookup)
                    return alignmentScore(alignment: alignment, localCount: localStops.count, kmbCount: candidate.stops.count)
                        .map { KMBAlignmentCandidate(candidate: candidate, alignment: alignment, score: $0) }
                }
                let acceptable = alignments.filter { isAcceptableAlignment($0.score) }
                guard !acceptable.isEmpty else {
                    if let rejected = alignments.max(by: { $0.score.coverage < $1.score.coverage }) {
                        let score = rejected.score
                        rejectedAlignmentDetails.append(KMBRejectedAlignmentDetail(
                            routeId: route.id, routeNumber: route.number, journeyId: journey.id,
                            bound: bestBound, serviceType: rejected.candidate.serviceType,
                            transitGoCount: localStops.count, kmbCount: rejected.candidate.stops.count,
                            matchedCount: score.matchedCount, transitGoOnlyCount: score.transitGoOnlyCount,
                            kmbOnlyCount: score.kmbOnlyCount, coverage: score.coverage,
                            averageDistance: score.averageDistance, maximumDistance: score.maximumDistance
                        ))
                    }
                    noMatchingServiceJourneys.append(KMBNoMatchingServiceJourney(
                        routeId: route.id, routeNumber: route.number, journeyId: journey.id,
                        bound: bestBound, transitGoCount: localStops.count
                    ))
                    continue
                }
                guard let winner = bestAcceptableAlignment(acceptable) else {
                    ambiguousJourneys.append(KMBAmbiguousJourney(
                        routeId: route.id, routeNumber: route.number, journeyId: journey.id,
                        bound: bestBound, transitGoCount: localStops.count,
                        reason: .indistinguishableServices,
                        identicalStopSequences: haveIdenticalStopSequences(acceptable.map(\.candidate)),
                        candidates: acceptable.map {
                            KMBAmbiguousCandidate(serviceType: $0.candidate.serviceType,
                                                  averageDistance: $0.score.averageDistance)
                        }
                    ))
                    continue
                }

                references += makeAlignedReferences(journey: journey, alignment: winner.alignment,
                                                    kmbStopLookup: kmbStopLookup, serviceType: winner.candidate.serviceType,
                                                    operatorId: operatorId, operatorDirection: bestBound)
                alignmentResolvedJourneys += 1
                let score = winner.score
                alignmentResolvedDetails.append(KMBAlignmentResolvedDetail(
                    routeId: route.id, routeNumber: route.number, journeyId: journey.id,
                    bound: bestBound, serviceType: winner.candidate.serviceType, matchedCount: score.matchedCount,
                    transitGoOnlyCount: score.transitGoOnlyCount, kmbOnlyCount: score.kmbOnlyCount,
                    coverage: score.coverage, averageDistance: score.averageDistance, maximumDistance: score.maximumDistance
                ))
            }
        }

            // MARK: - Result
            
            return KMBOperatorStopReferenceBuildResult(
                references: references,
                
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

            guard score.maximumDistance <= 700 else { return false }

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
                score.averageDistance <= 400 {

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

}

// MARK: - Internal Candidates

private struct KMBServiceCandidate {

    let bound: String
    let serviceType: String
    let stops: [KMBRouteStopRecord]
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
    enum Reason: String {
        case tiedDirectionEndpoints
        case indistinguishableServices
    }

    let routeId: String
    let routeNumber: String
    let journeyId: String

    let bound: String
    let transitGoCount: Int

    let reason: Reason

    let identicalStopSequences: Bool

    let candidates:
        [KMBAmbiguousCandidate]
}

struct KMBAmbiguousCandidate {

    let serviceType: String
    let averageDistance: Double
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
