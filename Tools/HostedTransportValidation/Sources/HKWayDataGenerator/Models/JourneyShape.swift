//
//  JourneyShape.swift
//  HK Way
//

import Foundation

struct JourneyShape: Codable {
    let journeyId: String
    let coordinates: [JourneyShapeCoordinate]
}

struct JourneyShapeCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    init(
        latitude: Double,
        longitude: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }

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
