//
//  KMBStopAPI.swift.swift
//  HK Way
//
//  Created by Ken on 12/8/2026.
//

import Foundation

struct KMBStopRecord: Codable, Sendable {

    let stop: String

    let nameEnglish: String
    let nameTraditional: String
    let nameSimplified: String

    let latitude: String
    let longitude: String

    enum CodingKeys: String, CodingKey {
        case stop

        case nameEnglish = "name_en"
        case nameTraditional = "name_tc"
        case nameSimplified = "name_sc"

        case latitude = "lat"
        case longitude = "long"
    }

    var latitudeValue: Double? {
        Double(latitude)
    }

    var longitudeValue: Double? {
        Double(longitude)
    }
}

private struct KMBStopListResponse: Codable {

    let type: String
    let version: String
    let generatedTimestamp: String
    let data: [KMBStopRecord]

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case generatedTimestamp = "generated_timestamp"
        case data
    }
}

private struct KMBStopResponse: Codable {

    let type: String
    let version: String
    let generatedTimestamp: String
    let data: KMBStopRecord

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case generatedTimestamp = "generated_timestamp"
        case data
    }
}

struct KMBStopAPI {

    func fetchAll() async throws -> [KMBStopRecord] {

        guard let url = URL(
            string:
                "https://data.etabus.gov.hk/v1/transport/kmb/stop"
        ) else {
            throw KMBStopAPIError.invalidURL
        }

        let (data, response) =
            try await URLSession.shared.data(
                from: url
            )

        try validate(response)

        let decoder = JSONDecoder()

        let responseObject =
            try decoder.decode(
                KMBStopListResponse.self,
                from: data
            )

        return responseObject.data
    }

    func fetch(
        stopId: String
    ) async throws -> KMBStopRecord {

        guard let url = URL(
            string:
                "https://data.etabus.gov.hk/v1/transport/kmb/stop/\(stopId)"
        ) else {
            throw KMBStopAPIError.invalidURL
        }

        let (data, response) =
            try await URLSession.shared.data(
                from: url
            )

        try validate(response)

        let decoder = JSONDecoder()

        let responseObject =
            try decoder.decode(
                KMBStopResponse.self,
                from: data
            )

        return responseObject.data
    }

    private func validate(
        _ response: URLResponse
    ) throws {

        guard
            let httpResponse =
                response as? HTTPURLResponse,
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw KMBStopAPIError.invalidResponse
        }
    }
}

enum KMBStopAPIError: Error {
    case invalidURL
    case invalidResponse
}
