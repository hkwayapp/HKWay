//
//  RawTransportStop.swift
//  HK Way
//
//  Created by Ken on 7/8/2026.
//

import Foundation

public struct RawTransportStop: Codable {
    
    public let stopId: String?

    public let nameEnglish: String?
    public let nameTraditional: String?
    public let nameSimplified: String?

    public let latitude: Double?
    public let longitude: Double?

    public let sequence: Int?

    public init(
        stopId: String?,
        nameEnglish: String?,
        nameTraditional: String?,
        nameSimplified: String?,
        latitude: Double?,
        longitude: Double?,
        sequence: Int?
    ) {
        self.stopId = stopId
        self.nameEnglish = nameEnglish
        self.nameTraditional = nameTraditional
        self.nameSimplified = nameSimplified
        self.latitude = latitude
        self.longitude = longitude
        self.sequence = sequence
    }
}
