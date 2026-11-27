//
//  Stop.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct Stop: Codable {

    let id: String

    let nameEnglish: String
    let nameTraditional: String
    let nameSimplified: String

    let latitude: Double
    let longitude: Double

    let regionId: String?
    let districtId: String?

    init(
        id: String,
        nameEnglish: String,
        nameTraditional: String,
        nameSimplified: String,
        latitude: Double,
        longitude: Double,
        regionId: String? = nil,
        districtId: String? = nil
    ) {
        self.id = id
        self.nameEnglish = nameEnglish
        self.nameTraditional = nameTraditional
        self.nameSimplified = nameSimplified
        self.latitude = latitude
        self.longitude = longitude
        self.regionId = regionId
        self.districtId = districtId
    }

}
