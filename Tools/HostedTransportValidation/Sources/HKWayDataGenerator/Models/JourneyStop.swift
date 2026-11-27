//
//  JourneyStop.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct JourneyStop: Codable {

    let journeyId: String
    let stopId: String
    let sequence: Int
    let stopPickDrop: String?

    init(
        journeyId: String,
        stopId: String,
        sequence: Int,
        stopPickDrop: String? = nil
    ) {
        self.journeyId = journeyId
        self.stopId = stopId
        self.sequence = sequence
        self.stopPickDrop = stopPickDrop
    }

}
