//
//  RouteReader.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct RouteReader {

    func read() throws -> [Route] {

        guard let url = Bundle.module.url(
            forResource: "routes",
            withExtension: "json"
        ) else {
            fatalError("routes.json not found")
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder().decode(
            [Route].self,
            from: data
        )
    }
}
