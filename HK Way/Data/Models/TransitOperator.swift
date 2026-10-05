//
//  TransitOperator.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct TransitOperator: Codable {
    let id: String
    let nameEnglish: String
    let nameSimplified: String
    let nameTraditional: String
    let transportTypes: [String]
}
