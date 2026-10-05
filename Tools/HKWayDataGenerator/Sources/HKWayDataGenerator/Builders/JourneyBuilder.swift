//
//  JourneyBuilder.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct JourneyBuilder {

    let reader = JourneyReader()
    let validator = JourneyValidator()

    func build() throws -> [Journey] {

        let journeys = try reader.read()

        validator.validate(journeys)

        return journeys
    }

}
