//
//  TransitJourneyStop.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct TransitJourneyStop: Codable {
    let journeyId: String
    let sequence: Int
    let stopId: String
    let stopPickDrop: String?
}
