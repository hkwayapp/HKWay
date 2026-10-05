//
//  TransitJourneyShape.swift
//  HK Way
//

import Foundation

struct TransitJourneyShape: Codable, Sendable {
    let journeyId: String
    let coordinates: [TransitJourneyShapeCoordinate]
}

struct TransitJourneyShapeCoordinate: Codable, Sendable {
    let latitude: Double
    let longitude: Double

    init(from decoder: Decoder) throws {

        var container = try decoder
            .unkeyedContainer()

        latitude = try container.decode(Double.self)
        longitude = try container.decode(Double.self)

        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Expected [latitude, longitude]"
            )
        }
    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.unkeyedContainer()
        try container.encode(latitude)
        try container.encode(longitude)
    }
}
