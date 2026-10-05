//
//  CTBStopAPI.swift
//  HKWayDataGenerator
//
//  Created by Ken on 15/8/2026.
//

import Foundation

struct CTBStopRecord: Codable, Sendable {

    let stop: String

    let nameEnglish: String
    let nameTraditional: String
    let nameSimplified: String

    let latitude: String
    let longitude: String

    let dataTimestamp: String?
    
    enum CodingKeys: String, CodingKey {
        case stop
        case nameEnglish = "name_en"
        case nameTraditional = "name_tc"
        case nameSimplified = "name_sc"
        case latitude = "lat"
        case longitude = "long"
        case dataTimestamp = "data_timestamp"
    }
    
    var latitudeValue: Double? {
        Double(latitude)
    }

    var longitudeValue: Double? {
        Double(longitude)
    }
}

private struct CTBStopResponse: Codable {

    let type: String
    let version: String
    let generatedTimestamp: String
    let data: CTBStopRecord

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case generatedTimestamp = "generated_timestamp "
        case data
    }
}

struct CTBStopAPI {

    func fetch(
        stopId: String
    ) async throws -> CTBStopRecord {

        guard let url = URL(
            string:
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/stop/\(stopId)"
        ) else {
            throw CTBStopAPIError.invalidURL
        }

        let (data, response) =
            try await URLSession.shared.data(
                from: url
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse,
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw CTBStopAPIError.invalidResponse
        }

        let responseObject =
            try JSONDecoder().decode(
                CTBStopResponse.self,
                from: data
            )

        return responseObject.data
    }
}

enum CTBStopAPIError: Error {
    case invalidURL
    case invalidResponse
}
