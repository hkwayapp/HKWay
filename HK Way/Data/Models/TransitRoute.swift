//
//  TransitRoute.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct TransitRoute: Codable {
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
