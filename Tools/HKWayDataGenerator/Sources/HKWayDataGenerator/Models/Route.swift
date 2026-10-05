//
//  Route.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct Route: Codable {
    let id: String
    let number: String
    let operatorIds: [String]

    let originEnglish: String
    let originTraditional: String
    let originSimplified: String

    let destinationEnglish: String
    let destinationTraditional: String
    let destinationSimplified: String
}
