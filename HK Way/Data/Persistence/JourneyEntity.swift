//
//  JourneyEntity.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
import SwiftData

@Model
final class JourneyEntity {

    @Attribute(.unique)
    var id: String

    var direction: String
    var serviceType: String
    var adultFullFareCents: Int?
    var scheduledDurationMinutes: Int?
    var sectionFareTiersData: Data?

    var sectionFareTiers: [TransitSectionFareTier]? {
        guard let sectionFareTiersData else {
            return nil
        }

        return try? JSONDecoder().decode(
            [TransitSectionFareTier].self,
            from: sectionFareTiersData
        )
    }

    func boardingFareCents(
        at stopSequence: Int
    ) -> Int? {
        sectionFareTiers?
            .filter {
                $0.boardingStopSequence <= stopSequence
            }
            .max {
                $0.boardingStopSequence <
                    $1.boardingStopSequence
            }?
            .fareCents
            ?? adultFullFareCents
    }

    @Relationship(inverse: \RouteEntity.journeys)
    var route: RouteEntity?

    var originStop: StopEntity?
    var destinationStop: StopEntity?

    var journeyStops: [JourneyStopEntity] = []

    init(
        id: String,
        direction: String,
        serviceType: String,
        adultFullFareCents: Int? = nil,
        scheduledDurationMinutes: Int? = nil,
        sectionFareTiers: [TransitSectionFareTier]? = nil
    ) {
        self.id = id
        self.direction = direction
        self.serviceType = serviceType
        self.adultFullFareCents = adultFullFareCents
        self.scheduledDurationMinutes = scheduledDurationMinutes
        self.sectionFareTiersData = sectionFareTiers.flatMap {
            try? JSONEncoder().encode($0)
        }
    }
}
