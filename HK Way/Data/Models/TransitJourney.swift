//
//  TransitJourney.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct TransitJourney: Codable {
    let destinationStopId: String
    let direction: String
    let id: String
    let originStopId: String
    let routeId: String
    let serviceType: String
    let adultFullFareCents: Int?
    let scheduledDurationMinutes: Int?
    let sectionFareTiers: [TransitSectionFareTier]?
}
