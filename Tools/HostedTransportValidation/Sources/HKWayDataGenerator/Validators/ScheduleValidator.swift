//
//  ScheduleValidator.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct ScheduleValidator {

    func validate(_ schedules: [Schedule]) {

        var ids = Set<String>()

        for schedule in schedules {

            guard ids.insert(schedule.id).inserted else {
                fatalError("Duplicate Schedule ID: \(schedule.id)")
            }

            guard !schedule.id.isEmpty else {
                fatalError("Schedule ID cannot be empty")
            }

            guard !schedule.journeyId.isEmpty else {
                fatalError("Journey ID cannot be empty")
            }

            guard !schedule.departureTime.isEmpty else {
                fatalError("Departure time cannot be empty")
            }
        }
    }
}
