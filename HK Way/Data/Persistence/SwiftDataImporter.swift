//
//  SwiftDataImporter.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
import SwiftData

@MainActor
struct SwiftDataImporter {

    // MARK: - Operators

    func importOperators(
        from sourceOperators: [TransitOperator],
        into modelContext: ModelContext
    ) async throws {

        let existingOperators = try modelContext.fetch(
            FetchDescriptor<OperatorEntity>()
        )
        var operatorLookup = Dictionary(
            uniqueKeysWithValues: existingOperators.map { ($0.id, $0) }
        )

        for (index, source) in sourceOperators.enumerated() {
            if operatorLookup[source.id] == nil {
                let entity = OperatorEntity(
                    id: source.id,
                    nameEnglish: source.nameEnglish,
                    nameSimplified: source.nameSimplified,
                    nameTraditional: source.nameTraditional
                )

                modelContext.insert(entity)
                operatorLookup[source.id] = entity
            }

            await yieldIfNeeded(after: index)
        }

        try modelContext.save()
    }


    // MARK: - Routes

    func importRoutes(
        from sourceRoutes: [TransitRoute],
        into modelContext: ModelContext
    ) async throws {

        let allOperators = try modelContext.fetch(
            FetchDescriptor<OperatorEntity>()
        )

        let operatorLookup = Dictionary(
            uniqueKeysWithValues: allOperators.map {
                ($0.id, $0)
            }
        )

        let existingRoutes = try modelContext.fetch(
            FetchDescriptor<RouteEntity>()
        )
        var routeLookup = Dictionary(
            uniqueKeysWithValues: existingRoutes.map { ($0.id, $0) }
        )

        for (index, source) in sourceRoutes.enumerated() {
            let route: RouteEntity

            if let existingRoute = routeLookup[source.id] {

                route = existingRoute

                route.number = source.number

                route.originEnglish = source.originEnglish
                route.originTraditional = source.originTraditional
                route.originSimplified = source.originSimplified

                route.destinationEnglish = source.destinationEnglish
                route.destinationTraditional = source.destinationTraditional
                route.destinationSimplified = source.destinationSimplified

            } else {

                route = RouteEntity(
                    id: source.id,
                    number: source.number,
                    originEnglish: source.originEnglish,
                    originTraditional: source.originTraditional,
                    originSimplified: source.originSimplified,
                    destinationEnglish: source.destinationEnglish,
                    destinationTraditional: source.destinationTraditional,
                    destinationSimplified: source.destinationSimplified
                )

                modelContext.insert(route)
                routeLookup[source.id] = route
            }

            route.operators = source.operatorIds.compactMap {
                operatorLookup[$0]
            }

            await yieldIfNeeded(after: index)
        }

        try modelContext.save()
    }


    // MARK: - Stops

    func importStops(
        from sourceStops: [TransitStop],
        into modelContext: ModelContext
    ) async throws {

        let existingStops = try modelContext.fetch(
            FetchDescriptor<StopEntity>()
        )
        var stopLookup = Dictionary(
            uniqueKeysWithValues: existingStops.map { ($0.id, $0) }
        )

        for (index, source) in sourceStops.enumerated() {
            let correctedCoordinate = StopCoordinateCorrection.values(
                stopID: source.id,
                latitude: source.latitude,
                longitude: source.longitude
            )
            if let stop = stopLookup[source.id] {

                stop.latitude = correctedCoordinate.latitude
                stop.longitude = correctedCoordinate.longitude
                stop.nameEnglish = source.nameEnglish
                stop.nameSimplified = source.nameSimplified
                stop.nameTraditional = source.nameTraditional
                stop.regionId = source.regionId
                stop.districtId = source.districtId

            } else {

                let stop = StopEntity(
                    id: source.id,
                    latitude: correctedCoordinate.latitude,
                    longitude: correctedCoordinate.longitude,
                    nameEnglish: source.nameEnglish,
                    nameSimplified: source.nameSimplified,
                    nameTraditional: source.nameTraditional,
                    regionId: source.regionId,
                    districtId: source.districtId
                )

                modelContext.insert(stop)
                stopLookup[source.id] = stop
            }

            await yieldIfNeeded(after: index)
        }

        try modelContext.save()
    }


    // MARK: - Journeys

    func importJourneys(
        from sourceJourneys: [TransitJourney],
        into modelContext: ModelContext
    ) async throws {

        let routes = try modelContext.fetch(
            FetchDescriptor<RouteEntity>()
        )

        let stops = try modelContext.fetch(
            FetchDescriptor<StopEntity>()
        )

        let routeLookup = Dictionary(
            uniqueKeysWithValues: routes.map {
                ($0.id, $0)
            }
        )

        let stopLookup = Dictionary(
            uniqueKeysWithValues: stops.map {
                ($0.id, $0)
            }
        )

        let existingJourneys = try modelContext.fetch(
            FetchDescriptor<JourneyEntity>()
        )
        var journeyLookup = Dictionary(
            uniqueKeysWithValues: existingJourneys.map { ($0.id, $0) }
        )

        for (index, source) in sourceJourneys.enumerated() {
            let journey: JourneyEntity

            if let existingJourney = journeyLookup[source.id] {

                journey = existingJourney
                journey.direction = source.direction
                journey.serviceType = source.serviceType
                journey.adultFullFareCents =
                    source.adultFullFareCents
                journey.scheduledDurationMinutes =
                    source.scheduledDurationMinutes
                journey.sectionFareTiersData =
                    source.sectionFareTiers.flatMap {
                        try? JSONEncoder().encode($0)
                    }

            } else {

                journey = JourneyEntity(
                    id: source.id,
                    direction: source.direction,
                    serviceType: source.serviceType,
                    adultFullFareCents:
                        source.adultFullFareCents,
                    scheduledDurationMinutes:
                        source.scheduledDurationMinutes,
                    sectionFareTiers:
                        source.sectionFareTiers
                )

                modelContext.insert(journey)
                journeyLookup[source.id] = journey
            }

            journey.route = routeLookup[source.routeId]
            journey.originStop = stopLookup[source.originStopId]
            journey.destinationStop = stopLookup[source.destinationStopId]

            await yieldIfNeeded(after: index)
        }

        try modelContext.save()
    }


    // MARK: - Journey Stops

    func importJourneyStops(
        from sourceJourneyStops: [TransitJourneyStop],
        into modelContext: ModelContext
    ) async throws {

        let journeys = try modelContext.fetch(
            FetchDescriptor<JourneyEntity>()
        )

        let stops = try modelContext.fetch(
            FetchDescriptor<StopEntity>()
        )

        let existingJourneyStops = try modelContext.fetch(
            FetchDescriptor<JourneyStopEntity>()
        )

        let journeyLookup = Dictionary(
            uniqueKeysWithValues: journeys.map {
                ($0.id, $0)
            }
        )

        let stopLookup = Dictionary(
            uniqueKeysWithValues: stops.map {
                ($0.id, $0)
            }
        )

        var journeyStopLookup = Dictionary(
            uniqueKeysWithValues: existingJourneyStops.map {
                ($0.id, $0)
            }
        )

        for (index, source) in sourceJourneyStops.enumerated() {

            let entityId =
                "\(source.journeyId)|\(source.sequence)"

            let entity: JourneyStopEntity

            if let existing = journeyStopLookup[entityId] {

                entity = existing
                entity.sequence = source.sequence
                entity.stopPickDrop = source.stopPickDrop

            } else {

                entity = JourneyStopEntity(
                    id: entityId,
                    sequence: source.sequence,
                    stopPickDrop: source.stopPickDrop
                )

                modelContext.insert(entity)

                journeyStopLookup[entityId] = entity
            }

            entity.journey = journeyLookup[source.journeyId]
            entity.stop = stopLookup[source.stopId]

            await yieldIfNeeded(after: index)
        }

        try modelContext.save()
    }


    // MARK: - Schedules

    func importSchedules(
        from sourceSchedules: [TransitSchedule],
        into modelContext: ModelContext
    ) async throws {

        let journeys = try modelContext.fetch(
            FetchDescriptor<JourneyEntity>()
        )

        let journeyLookup = Dictionary(
            uniqueKeysWithValues: journeys.map {
                ($0.id, $0)
            }
        )

        let existingSchedules = try modelContext.fetch(
            FetchDescriptor<ScheduleEntity>()
        )

        var scheduleLookup = Dictionary(
            uniqueKeysWithValues: existingSchedules.map {
                ($0.id, $0)
            }
        )

        for (index, source) in sourceSchedules.enumerated() {

            let schedule: ScheduleEntity

            if let existing = scheduleLookup[source.id] {

                schedule = existing
                schedule.serviceType = source.serviceType
                schedule.departureTime = source.departureTime

            } else {

                schedule = ScheduleEntity(
                    id: source.id,
                    serviceType: source.serviceType,
                    departureTime: source.departureTime
                )

                modelContext.insert(schedule)

                scheduleLookup[source.id] = schedule
            }

            schedule.journey = journeyLookup[source.journeyId]

            await yieldIfNeeded(after: index)
        }

        try modelContext.save()
    }
    
    // MARK: - Operator Stop References

    func importOperatorStopReferences(
        from sourceReferences: [TransitOperatorStopReference],
        into modelContext: ModelContext
    ) async throws {

        // The operator-stop-reference JSON is a complete
        // snapshot of the current dataset.
        //
        // Remove references from the previous dataset
        // before importing the new snapshot.

        let existingReferences =
            try modelContext.fetch(
                FetchDescriptor<
                    OperatorStopReferenceEntity
                >()
            )

        for (index, reference) in existingReferences.enumerated() {
            modelContext.delete(reference)
            await yieldIfNeeded(after: index)
        }

        try modelContext.save()

        // Import the current dataset snapshot.

        for (index, source) in sourceReferences.enumerated() {

            let publicStopCode = source.operatorId == "KMB"
                ? source.publicStopCode
                : nil

            let entity =
                OperatorStopReferenceEntity(
                    operatorId:
                        source.operatorId,
                    journeyId:
                        source.journeyId,
                    stopId:
                        source.stopId,
                    sequence:
                        source.sequence,
                    operatorStopId:
                        source.operatorStopId,
                    publicStopCode:
                        publicStopCode,
                    operatorLatitude:
                        source.operatorLatitude,
                    operatorLongitude:
                        source.operatorLongitude,
                    operatorServiceType:
                        source.operatorServiceType,
                    operatorDirection:
                        source.operatorDirection
                )

            modelContext.insert(entity)
            await yieldIfNeeded(after: index)
        }

        let journeyStops = try modelContext.fetch(
            FetchDescriptor<JourneyStopEntity>()
        )

        let journeyStopLookup = Dictionary(
            uniqueKeysWithValues: journeyStops.map {
                ($0.id, $0)
            }
        )

        for (index, journeyStop) in journeyStops.enumerated() {
            journeyStop.publicStopCode = nil
            await yieldIfNeeded(after: index)
        }

        var kmbReferenceIndex = 0
        for source in sourceReferences where source.operatorId == "KMB" {
            guard let publicStopCode = source.publicStopCode else {
                continue
            }

            journeyStopLookup[
                "\(source.journeyId)|\(source.sequence)"
            ]?.publicStopCode = publicStopCode

            await yieldIfNeeded(after: kmbReferenceIndex)
            kmbReferenceIndex += 1
        }

        try modelContext.save()
    }

    private func yieldIfNeeded(after index: Int) async {
        if index > 0, index.isMultiple(of: 50) {
            await Task.yield()
        }
    }
}
