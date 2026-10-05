//
//  TransitStop.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct TransitStop: Codable {
    let id: String
    let latitude: Double
    let longitude: Double
    let nameEnglish: String
    let nameSimplified: String
    let nameTraditional: String
    let regionId: String?
    let districtId: String?
}

enum StopCoordinateCorrection {
    static func values(
        stopID: String,
        latitude: Double,
        longitude: Double
    ) -> (latitude: Double, longitude: Double) {
        switch stopID {
        // DATA.GOV.HK stop 12897 is the KMB stop TW371. The generic stop
        // coordinate points inside Tsuen King Garden; all TW371 operator
        // references place the boarding point on the roadside here.
        case "12897":
            (22.375776, 114.106972)
        default:
            (latitude, longitude)
        }
    }
}
