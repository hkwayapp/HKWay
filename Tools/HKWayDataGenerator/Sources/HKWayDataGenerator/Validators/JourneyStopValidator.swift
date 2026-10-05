//
//  JourneyStopValidator.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct JourneyStopValidator {

    func validate(_ journeyStops: [JourneyStop]) {

        for item in journeyStops {

            guard !item.journeyId.isEmpty else {
                fatalError("Journey ID cannot be empty")
            }

            guard !item.stopId.isEmpty else {
                fatalError("Stop ID cannot be empty")
            }

            guard item.sequence > 0 else {
                fatalError("Sequence must be greater than 0")
            }
        }
    }
}
