//
//  JourneyReader.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct JourneyReader {

    func read() throws -> [Journey] {

        guard let url = Bundle.module.url(
            forResource: "journeys",
            withExtension: "json"
        ) else {
            fatalError("journeys.json not found")
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder().decode(
            [Journey].self,
            from: data
        )
    }

}
