//
//  RealDataBuilder.swift
//  HK Way
//
//  Created by Ken on 10/8/2026.
//

import Foundation

struct RealDataBuilder {

    let operatorBuilder = RealOperatorBuilder()
    let routeBuilder = RealRouteBuilder()
    let journeyBuilder = RealJourneyBuilder()
    let journeyStopBuilder = RealJourneyStopBuilder()
    let stopBuilder = RealStopBuilder()

    let kmbOperatorStopReferenceBuilder =
        KMBOperatorStopReferenceBuilder()

    let ctbOperatorStopReferenceBuilder =
        CTBOperatorStopReferenceBuilder()

    let nlbOperatorStopReferenceBuilder =
        NLBOperatorStopReferenceBuilder()

    let validator: MasterDataValidating =
        MasterDataValidator()

    func build() async throws -> MasterData {

        // Build the core HK Way data once.

        let operators =
            try operatorBuilder.build()

        let routes =
            try routeBuilder.build()

        let journeys =
            try journeyBuilder.build()

        let journeyStops =
            try journeyStopBuilder.build()

        let rawStops =
            try stopBuilder.build()

        let districtBoundaries = try await
            DistrictBoundaryClient().fetch()

        let stops = StopGeographyEnricher(
            boundaries: districtBoundaries
        ).enrich(rawStops)

        // Build KMB operator-specific stop references.

        let kmbReferenceResult =
            try await kmbOperatorStopReferenceBuilder.buildAll(
                routes: routes,
                journeys: journeys,
                journeyStops: journeyStops,
                stops: stops
            )

        let ctbReferenceResult =
            try await ctbOperatorStopReferenceBuilder.buildAll(
                routes: routes,
                journeys: journeys,
                journeyStops: journeyStops,
                stops: stops
            )

        let nlbReferenceResult =
            try await nlbOperatorStopReferenceBuilder.buildAll(
                routes: routes,
                journeys: journeys,
                journeyStops: journeyStops,
                stops: stops
            )

        print("")
        print("*** KMB operator stop references ***")

        print(
            "References:",
            kmbReferenceResult.references.count
        )

        print(
            "Unmatched routes:",
            kmbReferenceResult.unmatchedRoutes.count
        )

        print(
            "Unmatched journeys:",
            kmbReferenceResult.unmatchedJourneys.count
        )

        print(
            "Ambiguous journeys:",
            kmbReferenceResult.ambiguousJourneys.count
        )

        print(
            "No matching service:",
            kmbReferenceResult
                .noMatchingServiceJourneys
                .count
        )

        print("")
        print("*** CTB operator stop references ***")

        print(
            "References:",
            ctbReferenceResult.references.count
        )

        print(
            "Matched journeys:",
            ctbReferenceResult.matchedJourneys
        )

        print(
            "Unmatched routes:",
            ctbReferenceResult.unmatchedRoutes.count
        )

        print(
            "Unmatched journeys:",
            ctbReferenceResult.unmatchedJourneys.count
        )

        print(
            "Ambiguous journeys:",
            ctbReferenceResult.ambiguousJourneys.count
        )

        print(
            "Rejected journeys:",
            ctbReferenceResult.rejectedJourneys.count
        )

        print("")
        print("*** NLB operator stop references ***")

        print(
            "References:",
            nlbReferenceResult.references.count
        )

        print(
            "Matched journeys:",
            nlbReferenceResult.matchedJourneys
        )

        print(
            "Unmatched routes:",
            nlbReferenceResult.unmatchedRoutes.count
        )

        print(
            "Unmatched journeys:",
            nlbReferenceResult.unmatchedJourneys.count
        )

        print(
            "Ambiguous journeys:",
            nlbReferenceResult.ambiguousJourneys.count
        )

        print(
            "Rejected journeys:",
            nlbReferenceResult.rejectedJourneys.count
        )
        
        let operatorStopReferences =
            kmbReferenceResult.references +
            ctbReferenceResult.references +
            nlbReferenceResult.references
    
        let masterData = MasterData(
            operators: operators,
            routes: routes,
            journeys: journeys,
            journeyStops: journeyStops,
            stops: stops,
            schedules: [],
            operatorStopReferences:
                operatorStopReferences
        )
        try validator.validate(masterData)

        return masterData
    }
}
