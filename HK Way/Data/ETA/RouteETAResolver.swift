//
//  RouteETAResolver.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import Foundation
import CoreLocation
import SwiftData

enum RouteETAResolverError: Error {
    case allProvidersFailed
}

struct RouteETAResult {

    let journey: JourneyEntity
    let journeyStop: JourneyStopEntity
    let stop: StopEntity

    let distanceMeters: CLLocationDistance

    // Primary reference kept for compatibility
    // with the existing UI.
    let reference: OperatorStopReferenceEntity

    // May contain ETA records from multiple
    // operators for jointly operated routes.
    let etaRecords: [TransitETA]
}

@MainActor
struct RouteETAResolver {

    // MARK: - Route + Location

    func resolve(
        route: RouteEntity,
        userLocation: CLLocation,
        modelContext: ModelContext
    ) async throws -> RouteETAResult? {

        var candidates:
            [NearbyRouteMatch] = []

        for journey in route.journeys {

            for journeyStop in journey.journeyStops {

                guard let stop =
                    journeyStop.stop
                else {
                    continue
                }

                let stopLocation =
                    CLLocation(
                        latitude: stop.latitude,
                        longitude: stop.longitude
                    )

                let distance =
                    userLocation.distance(
                        from: stopLocation
                    )

                candidates.append(
                    NearbyRouteMatch(
                        route: route,
                        journey: journey,
                        journeyStop: journeyStop,
                        stop: stop,
                        distanceMeters: distance
                    )
                )
            }
        }

        candidates.sort {
            $0.distanceMeters <
                $1.distanceMeters
        }

        // Search outward from the user's
        // location until we find a stop that
        // has at least one operator reference.

        for candidate in candidates {

            let references =
                try fetchReferences(
                    journey:
                        candidate.journey,
                    journeyStop:
                        candidate.journeyStop,
                    stop:
                        candidate.stop,
                    modelContext:
                        modelContext
                )

            guard !references.isEmpty else {
                continue
            }

            return try await resolve(
                match: candidate,
                references: references
            )
        }

        return nil
    }

    // MARK: - Journey + Location

    func resolve(
        journey: JourneyEntity,
        userLocation: CLLocation,
        modelContext: ModelContext
    ) async throws -> RouteETAResult? {
        guard let route = journey.route else {
            return nil
        }

        let candidates: [NearbyRouteMatch] = journey.journeyStops.compactMap {
            journeyStop -> NearbyRouteMatch? in
            guard let stop = journeyStop.stop else {
                return nil
            }

            let distance = userLocation.distance(
                from: CLLocation(
                    latitude: stop.latitude,
                    longitude: stop.longitude
                )
            )
            return NearbyRouteMatch(
                route: route,
                journey: journey,
                journeyStop: journeyStop,
                stop: stop,
                distanceMeters: distance
            )
        }
        .sorted { $0.distanceMeters < $1.distanceMeters }

        for candidate in candidates {
            let references = try fetchReferences(
                journey: journey,
                journeyStop: candidate.journeyStop,
                stop: candidate.stop,
                modelContext: modelContext
            )

            guard !references.isEmpty else {
                continue
            }

            return try await resolve(
                match: candidate,
                references: references
            )
        }

        return nil
    }

    // MARK: - Existing Nearby Match

    func resolve(
        match: NearbyRouteMatch,
        modelContext: ModelContext
    ) async throws -> RouteETAResult? {

        let references =
            try fetchReferences(
                journey:
                    match.journey,
                journeyStop:
                    match.journeyStop,
                stop:
                    match.stop,
                modelContext:
                    modelContext
            )

        guard !references.isEmpty else {
            return nil
        }

        return try await resolve(
            match: match,
            references: references
        )
    }

    // MARK: - Exact Journey Stop
    func resolve(
        journey: JourneyEntity,
        journeyStop: JourneyStopEntity,
        modelContext: ModelContext
    ) async throws -> RouteETAResult? {

        guard
            let route =
                journey.route,
            let stop =
                journeyStop.stop
        else {
            return nil
        }

        let references =
            try fetchReferences(
                journey: journey,
                journeyStop: journeyStop,
                stop: stop,
                modelContext: modelContext
            )

        guard !references.isEmpty else {
            return nil
        }

        let etaRecords =
            try await fetchETA(
                references: references,
                journey: journey,
                route: route
            )

        guard let primaryReference =
            references.first
        else {
            return nil
        }

        return RouteETAResult(
            journey: journey,
            journeyStop: journeyStop,
            stop: stop,
            distanceMeters: 0,
            reference: primaryReference,
            etaRecords: etaRecords
        )
    }


    // MARK: - Resolve Match

    private func resolve(
        match: NearbyRouteMatch,
        references:
            [OperatorStopReferenceEntity]
    ) async throws -> RouteETAResult? {

        let route =
            match.route

        let journey =
            match.journey

        let etaRecords =
            try await fetchETA(
                references: references,
                journey: journey,
                route: route
            )

        guard let primaryReference =
            references.first
        else {
            return nil
        }

        return RouteETAResult(
            journey:
                journey,
            journeyStop:
                match.journeyStop,
            stop:
                match.stop,
            distanceMeters:
                match.distanceMeters,
            reference:
                primaryReference,
            etaRecords:
                etaRecords
        )
    }

    // MARK: - Fetch References

    private func fetchReferences(
        journey: JourneyEntity,
        journeyStop: JourneyStopEntity,
        stop: StopEntity,
        modelContext: ModelContext
    ) throws
        -> [OperatorStopReferenceEntity] {

        let journeyId =
            journey.id

        let sequence =
            journeyStop.sequence

        let stopId =
            stop.id

        let descriptor =
            FetchDescriptor<
                OperatorStopReferenceEntity
            >(
                predicate: #Predicate {
                    $0.journeyId == journeyId &&
                    $0.sequence == sequence &&
                    $0.stopId == stopId
                }
            )

        return try modelContext.fetch(
            descriptor
        )
    }

    // MARK: - Fetch ETA From All Operators

    private func fetchETA(
        references:
            [OperatorStopReferenceEntity],
        journey: JourneyEntity,
        route: RouteEntity
    ) async throws -> [TransitETA] {

        let referenceSnapshots = references.map(
            ETAOperatorReference.init
        )

        let routeNumber = route.number

        let networkTask = Task.detached(
            priority: .userInitiated
        ) {
            try await Self.fetchETANetwork(
                references: referenceSnapshots,
                routeNumber: routeNumber
            )
        }

        return try await withTaskCancellationHandler {
            try await networkTask.value
        } onCancel: {
            networkTask.cancel()
        }
    }

    private nonisolated static func fetchETANetwork(
        references: [ETAOperatorReference],
        routeNumber: String
    ) async throws -> [TransitETA] {

        let etaProvider = ETAProvider()

        var combined:
            [TransitETA] = []

        var successfulProviderCount = 0

        for reference in references {

            do {

                let records =
                    try await etaProvider.fetchETA(
                        reference: reference,
                        routeNumber: routeNumber
                    )

                successfulProviderCount += 1

                combined.append(
                    contentsOf: records
                )

            } catch {

                // One operator failing should not
                // prevent another operator from
                // returning ETA for a joint route.
            }
        }

        guard successfulProviderCount > 0 else {
            throw RouteETAResolverError
                .allProvidersFailed
        }

        // Put the soonest valid ETA first.
        // Records without an ETA remain at
        // the end of the collection.

        return combined.sorted {

            switch (
                $0.estimatedArrival,
                $1.estimatedArrival
            ) {

            case let (lhs?, rhs?):
                return lhs < rhs

            case (.some, .none):
                return true

            case (.none, .some):
                return false

            case (.none, .none):
                return $0.sequence <
                    $1.sequence
            }
        }
    }
}
