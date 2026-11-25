//
//  CTBStopAPI.swift
//  HKWayDataGenerator
//
//  Created by Ken on 15/8/2026.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

private struct CTBStopResponse: Decodable {
    let type: String
    let data: CTBStopRecord
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
            try await DatasetHTTP.data(
                from: url, trackFailure: false
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

        do {
            return try Self.decode(data, stopId: stopId)
        } catch {
            print("CTB stop \(stopId): HTTP \(httpResponse.statusCode), invalid response: \(error)")
            throw error
        }
    }

    static func decode(_ data: Data, stopId: String) throws -> CTBStopRecord {
        let response = try JSONDecoder().decode(CTBStopResponse.self, from: data)
        guard response.type == "Stop", response.data.isValid(for: stopId) else {
            throw CTBStopAPIError.invalidResponse
        }
        return response.data
    }
}

enum CTBStopAPIError: Error {
    case invalidURL
    case invalidResponse
}
