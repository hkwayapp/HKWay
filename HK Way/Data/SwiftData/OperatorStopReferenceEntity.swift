//
//  OperatorStopReferenceEntity.swift
//  HK Way
//
//  Created by Ken on 13/8/2026.
//

import Foundation
import SwiftData

@Model
final class OperatorStopReferenceEntity {

    @Attribute(.unique)
    var id: String

    var operatorId: String
    var journeyId: String
    var stopId: String
    var sequence: Int
    var operatorStopId: String
    var publicStopCode: String?
    var operatorLatitude: Double?
    var operatorLongitude: Double?
    var operatorServiceType: String
    var operatorDirection: String

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
        self.id =
            "\(operatorId)|\(journeyId)|\(sequence)"

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
