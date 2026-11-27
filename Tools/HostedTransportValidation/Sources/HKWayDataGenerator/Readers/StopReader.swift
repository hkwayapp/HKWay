//
//  StopReader.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct StopReader {

    func read() throws -> [Stop] {

        guard let url = Bundle.module.url(
            forResource: "stops",
            withExtension: "json"
        ) else {
            fatalError("stops.json not found")
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder().decode(
            [Stop].self,
            from: data
        )
    }
}
