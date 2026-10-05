//
//  TransitOperatorStopReference.swift
//  HK Way
//
//  Created by Ken on 13/8/2026.
//

import Foundation

struct TransitOperatorStopReference: Codable {

    let operatorId: String
    let journeyId: String
    let stopId: String
    let sequence: Int
    let operatorStopId: String
    let publicStopCode: String?
    let operatorLatitude: Double?
    let operatorLongitude: Double?
    let operatorServiceType: String
    let operatorDirection: String
}
