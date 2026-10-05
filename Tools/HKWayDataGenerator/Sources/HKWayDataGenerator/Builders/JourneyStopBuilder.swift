//
//  JourneyStopBuilder.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct JourneyStopBuilder {

    let reader = JourneyStopReader()
    let validator = JourneyStopValidator()

    func build() throws -> [JourneyStop] {

        let journeyStops = try reader.read()

        validator.validate(journeyStops)

        return journeyStops
    }
}
