//
//  CTBRouteStopAPI.swift
//  HK Way
//
//  Created by Ken on 15/8/2026.
//

import Foundation

struct CTBRouteStopRecord: Codable, Sendable {

    let companyId: String
    let route: String
    let direction: String
    let sequence: Int
    let stop: String

    let dataTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case companyId = "co"
        case route
        case direction = "dir"
        case sequence = "seq"
        case stop
        case dataTimestamp = "data_timestamp"
    }
}

private struct CTBRouteStopResponse: Codable {

    let type: String
    let version: String

    let generatedTimestamp: String?

    let data: [CTBRouteStopRecord]

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case generatedTimestamp = "generated_timestamp "
        case data
    }
}

struct CTBRouteStopAPI {

    func fetch(
        route: String,
        direction: String
    ) async throws -> [CTBRouteStopRecord] {

        guard let url = URL(
            string:
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/route-stop/CTB/\(route)/\(direction)"
        ) else {
            throw CTBRouteStopAPIError.invalidURL
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
            throw CTBRouteStopAPIError.invalidResponse
        }

        let responseObject =
            try JSONDecoder().decode(
                CTBRouteStopResponse.self,
                from: data
            )

        return responseObject.data
    }
}

enum CTBRouteStopAPIError: Error {
    case invalidURL
    case invalidResponse
}
