//
//  RouteValidator.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct RouteValidator {

    func validate(
        _ routes: [Route]
    ) {

        var ids = Set<String>()

        for route in routes {

            guard ids.insert(route.id).inserted else {
                fatalError("Duplicate Route ID: \(route.id)")
            }

            guard !route.id.isEmpty else {
                fatalError("Route ID cannot be empty")
            }

            guard !route.number.isEmpty else {
                fatalError("Route number cannot be empty")
            }

        }

    }

}
