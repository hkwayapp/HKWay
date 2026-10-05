//
//  OperatorStopReference.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct OperatorStopReference: Codable {

    let operatorId: String

    // HK Way journey
    let journeyId: String

    // HK Way canonical stop
    let stopId: String

    // Position within this journey
    let sequence: Int

    // Operator-specific stop ID used by its API
    let operatorStopId: String

    // Public-facing boarding-point code shown on KMB stop poles,
    // for example "TW377". Other operators omit this field.
    let publicStopCode: String?

    // Operator-authoritative boarding-point coordinates.
    // Optional so older datasets and operators without coordinates
    // remain compatible.
    let operatorLatitude: Double?
    let operatorLongitude: Double?

    // Operator-specific service variant.
    // For KMB this is the numeric service_type,
    // stored as text so the model remains operator-neutral.
    let operatorServiceType: String

    // Operator-specific direction / bound.
    //
    // Examples:
    // KMB / LWB: "O" or "I"
    // CTB: direction returned by the CTB route API.
    let operatorDirection: String

    init(
        operatorId: String,
        journeyId: String,
        stopId: String,
        sequence: Int,
        operatorStopId: String,
        publicStopCode: String? = nil,
        operatorLatitude: Double? = nil,
        operatorLongitude: Double? = nil,
        operatorServiceType: String,
        operatorDirection: String
    ) {
        self.operatorId = operatorId
        self.journeyId = journeyId
        self.stopId = stopId
        self.sequence = sequence
        self.operatorStopId = operatorStopId
        self.publicStopCode = publicStopCode
        self.operatorLatitude = operatorLatitude
        self.operatorLongitude = operatorLongitude
        self.operatorServiceType = operatorServiceType
        self.operatorDirection = operatorDirection
    }
}
