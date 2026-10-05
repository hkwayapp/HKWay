//
//  ScheduleEntity.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
import SwiftData

@Model
final class ScheduleEntity {

    @Attribute(.unique)
    var id: String

    var serviceType: String
    var departureTime: String

    var journey: JourneyEntity?

    init(
        id: String,
        serviceType: String,
        departureTime: String
    ) {
        self.id = id
        self.serviceType = serviceType
        self.departureTime = departureTime
    }
}
