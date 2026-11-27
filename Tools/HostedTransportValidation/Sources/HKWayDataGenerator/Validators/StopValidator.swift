//
//  StopValidator.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct StopValidator {

    func validate(_ stops: [Stop]) {

        var ids = Set<String>()

        for stop in stops {

            guard ids.insert(stop.id).inserted else {
                fatalError("Duplicate Stop ID: \(stop.id)")
            }

            guard !stop.id.isEmpty else {
                fatalError("Stop ID cannot be empty")
            }

            guard !stop.nameEnglish.isEmpty else {
                fatalError("Stop English name cannot be empty")
            }
        }
    }
}
