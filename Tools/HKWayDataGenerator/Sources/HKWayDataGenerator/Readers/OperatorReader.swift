//
//  OperatorReader.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct OperatorReader {

    func read() throws -> [Operator] {

        guard let url = Bundle.module.url(
            forResource: "operators",
            withExtension: "json"
        ) else {
            throw NSError(
                domain: "OperatorReader",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "operators.json not found"
                ]
            )
        }

        let data = try Data(contentsOf: url)

        return try JSONDecoder()
            .decode([Operator].self, from: data)
    }
}
