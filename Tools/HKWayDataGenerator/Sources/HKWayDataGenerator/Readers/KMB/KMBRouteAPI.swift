//
//  KMBRouteAPI.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct KMBRouteRecord: Codable, Sendable {

    let route: String
    let bound: String
    let serviceType: String

    let origEnglish: String
    let origTraditional: String
    let origSimplified: String

    let destEnglish: String
    let destTraditional: String
    let destSimplified: String

    enum CodingKeys: String, CodingKey {
        case route
        case bound
        case serviceType = "service_type"

        case origEnglish = "orig_en"
        case origTraditional = "orig_tc"
        case origSimplified = "orig_sc"

        case destEnglish = "dest_en"
        case destTraditional = "dest_tc"
        case destSimplified = "dest_sc"
    }
}

private struct KMBRouteResponse: Codable {

    let type: String
    let version: String
    let generatedTimestamp: String
    let data: [KMBRouteRecord]

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case generatedTimestamp = "generated_timestamp"
        case data
    }
}

struct KMBRouteAPI {

    func fetchAll() async throws -> [KMBRouteRecord] {

        guard let url = URL(
            string:
                "https://data.etabus.gov.hk/v1/transport/kmb/route/"
        ) else {
            throw KMBRouteAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(
            from: url
        )

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw KMBRouteAPIError.invalidResponse
        }

        let decoder = JSONDecoder()

        let responseObject = try decoder.decode(
            KMBRouteResponse.self,
            from: data
        )

        return responseObject.data
    }
}

enum KMBRouteAPIError: Error {
    case invalidURL
    case invalidResponse
}
