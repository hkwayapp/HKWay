//
//  JourneyValidator.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct JourneyValidator {

    func validate(
        _ journeys: [Journey]
    ) {

        var ids = Set<String>()

        for journey in journeys {

            guard ids.insert(journey.id).inserted else {
                fatalError("Duplicate Journey ID: \(journey.id)")
            }

            guard !journey.id.isEmpty else {
                fatalError("Journey ID cannot be empty")
            }

            guard !journey.routeId.isEmpty else {
                fatalError("Journey Route ID cannot be empty")
            }

        }

    }

}
