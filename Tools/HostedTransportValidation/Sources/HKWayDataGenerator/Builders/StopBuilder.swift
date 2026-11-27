//
//  StopBuilder.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct StopBuilder {

    let reader = StopReader()
    let validator = StopValidator()

    func build() throws -> [Stop] {

        let stops = try reader.read()

        validator.validate(stops)

        return stops
    }
}
