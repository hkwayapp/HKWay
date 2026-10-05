//
//  RouteBuilder.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct RouteBuilder {

    let reader = RouteReader()
    let validator = RouteValidator()

    func build() throws -> [Route] {

        let routes = try reader.read()

        validator.validate(routes)

        return routes
    }

}
