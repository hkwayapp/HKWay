//
//  TransitSchedule.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct TransitSchedule: Codable {
    let id: String
    let journeyId: String
    let serviceType: String
    let departureTime: String
}
