//
//  MasterDataValidator.swift
//  HK Way
//
//  Created by Ken on 7/8/2026.
//

struct MasterDataValidator: MasterDataValidating {
    
    func validate(_ data: MasterData) throws {
        try validateRoutes(data)
        try validateJourneys(data)
        try validateJourneyStops(data)
        try validateSchedules(data)
    }

    private func validateRoutes(_ data: MasterData) throws {

        let operatorIDs = Set(data.operators.map { $0.id })

        var errors: [MasterDataValidationError] = []

        for route in data.routes {

            for operatorID in route.operatorIds {

                if !operatorIDs.contains(operatorID) {

                    errors.append(
                        .missingOperatorReference(
                            "Route \(route.number) references missing operator \(operatorID)"
                        )
                    )
                }
            }
        }

        if !errors.isEmpty {
            throw MasterDataValidationErrors(errors: errors)
        }
    }

    private func validateJourneys(_ data: MasterData) throws {

        let routeIDs = Set(data.routes.map { $0.id })

        var errors: [MasterDataValidationError] = []

        for journey in data.journeys {

            if !routeIDs.contains(journey.routeId) {

                errors.append(
                    .missingRouteReference(
                        "Journey \(journey.id) references missing route \(journey.routeId)"
                    )
                )
            }
        }

        if !errors.isEmpty {
            throw MasterDataValidationErrors(errors: errors)
        }
    }

    private func validateJourneyStops(_ data: MasterData) throws {

        let journeyIDs = Set(data.journeys.map { $0.id })
        let stopIDs = Set(data.stops.map { $0.id })

        var errors: [MasterDataValidationError] = []

        for journeyStop in data.journeyStops {

            if !journeyIDs.contains(journeyStop.journeyId) {

                errors.append(
                    .missingJourneyReference(
                        "JourneyStop references missing journey \(journeyStop.journeyId)"
                    )
                )
            }

            if !stopIDs.contains(journeyStop.stopId) {

                errors.append(
                    .missingStopReference(
                        "JourneyStop references missing stop \(journeyStop.stopId)"
                    )
                )
            }
        }

        if !errors.isEmpty {
            throw MasterDataValidationErrors(errors: errors)
        }
    }

    private func validateSchedules(_ data: MasterData) throws {
        
        let journeyIDs = Set(data.journeys.map { $0.id })

        var errors: [MasterDataValidationError] = []

        for schedule in data.schedules {

            if !journeyIDs.contains(schedule.journeyId) {

                errors.append(
                    .missingJourneyReference(
                        "Schedule \(schedule.id) references missing journey \(schedule.journeyId)"
                    )
                )
            }
        }

        if !errors.isEmpty {
            throw MasterDataValidationErrors(errors: errors)
        }
    }
    
    
}
