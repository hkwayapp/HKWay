//
//  CTBRouteAPI.swift
//  HK Way
//
//  Created by Ken on 15/8/2026.
//

import Foundation

struct CTBRouteRecord: Codable, Sendable {

    let companyId: String
    let route: String

    let originTraditional: String
    let originEnglish: String
    let originSimplified: String?

    let destinationTraditional: String
    let destinationEnglish: String
    let destinationSimplified: String?

    let dataTimestamp: String?

    enum CodingKeys: String, CodingKey {

        case companyId = "co"
        case route

        case originTraditional = "orig_tc"
        case originEnglish = "orig_en"
        case originSimplified = "orig_sc"

        case destinationTraditional = "dest_tc"
        case destinationEnglish = "dest_en"
        case destinationSimplified = "dest_sc"

        case dataTimestamp = "data_timestamp"
    }
}

private struct CTBRouteListResponse: Codable {

    let type: String
    let version: String
    let generatedTimestamp: String?
    let data: [CTBRouteRecord]

    enum CodingKeys: String, CodingKey {
        case type
        case version

        // v1 API really contains a trailing space.
        case generatedTimestamp =
            "generated_timestamp "

        case data
    }
}

struct CTBRouteAPI {

    func fetchAll() async throws
        -> [CTBRouteRecord] {

        guard let url = URL(
            string:
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/route/CTB"
        ) else {
            throw CTBRouteAPIError.invalidURL
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
            throw CTBRouteAPIError.invalidResponse
        }

        let responseObject =
            try JSONDecoder().decode(
                CTBRouteListResponse.self,
                from: data
            )

        return responseObject.data
    }
}

enum CTBRouteAPIError: Error {
    case invalidURL
    case invalidResponse
}
