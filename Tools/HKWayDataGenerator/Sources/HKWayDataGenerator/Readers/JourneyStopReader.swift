//
//  JourneyStopReader.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct JourneyStopReader {

    func read() throws -> [JourneyStop] {

        guard let url = Bundle.module.url(
            forResource: "journey_stops",
            withExtension: "json"
        ) else {
            fatalError("journey_stops.json not found")
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder().decode(
            [JourneyStop].self,
            from: data
        )
    }
}
