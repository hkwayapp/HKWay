//
//  ScheduleReader.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct ScheduleReader {

    func read() throws -> [Schedule] {

        guard let url = Bundle.module.url(
            forResource: "schedules",
            withExtension: "json"
        ) else {
            fatalError("schedules.json not found")
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder().decode(
            [Schedule].self,
            from: data
        )
    }
}
