//
//  ScheduleBuilder.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct ScheduleBuilder {

    let reader = ScheduleReader()
    let validator = ScheduleValidator()

    func build() throws -> [Schedule] {

        let schedules = try reader.read()

        validator.validate(schedules)

        return schedules
    }
}
