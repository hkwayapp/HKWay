//
//  JourneyStopEntity.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
import SwiftData

@Model
final class JourneyStopEntity {

    @Attribute(.unique)
    var id: String

    var sequence: Int
    var publicStopCode: String?
    var stopPickDrop: String?
    var stop: StopEntity?

    @Relationship(inverse: \JourneyEntity.journeyStops)
    var journey: JourneyEntity?
    
    init(
        id: String,
        sequence: Int,
        publicStopCode: String? = nil,
        stopPickDrop: String? = nil
    ) {
        self.id = id
        self.sequence = sequence
        self.publicStopCode = publicStopCode
        self.stopPickDrop = stopPickDrop
    }
}
