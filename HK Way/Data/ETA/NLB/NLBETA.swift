//
//  NLBETA.swift
//  HK Way
//

import Foundation

struct NLBETAResponse: Decodable {

    let estimatedArrivals: [NLBETA]?
    let message: String?
}

struct NLBETA: Decodable {

    let estimatedArrivalTime: String
    let routeVariantName: String
    let departed: Int
    let noGPS: Int
    let wheelChair: Int
    let generateTime: String

    enum CodingKeys: String, CodingKey {
        case estimatedArrivalTime
        case routeVariantName
        case departed
        case noGPS
        case wheelChair
        case generateTime
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        estimatedArrivalTime = try container.decode(
            String.self,
            forKey: .estimatedArrivalTime
        )
        routeVariantName = try container.decode(
            String.self,
            forKey: .routeVariantName
        )
        departed = try container.decodeFlexibleInt(
            forKey: .departed
        )
        noGPS = try container.decodeFlexibleInt(
            forKey: .noGPS
        )
        wheelChair = try container.decodeFlexibleInt(
            forKey: .wheelChair
        )
        generateTime = try container.decode(
            String.self,
            forKey: .generateTime
        )
    }
}

private extension KeyedDecodingContainer {

    func decodeFlexibleInt(
        forKey key: Key
    ) throws -> Int {

        if let value = try? decode(
            Int.self,
            forKey: key
        ) {
            return value
        }

        let value = try decode(
            String.self,
            forKey: key
        )

        guard let integer = Int(value) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription:
                    "Expected an integer or integer string"
            )
        }

        return integer
    }
}
