//
//  KMBRouteStopAPI.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct KMBRouteStopRecord: Codable, Sendable {

    let route: String
       let bound: String
       let serviceType: String
       let seq: String
       let stop: String

       enum CodingKeys: String, CodingKey {
           case route
           case bound
           case serviceType = "service_type"
           case seq
           case stop
       }

    var sequence: Int? {
           Int(seq)
       }
}

private struct KMBRouteStopResponse: Codable {

    let type: String
    let version: String
    let generatedTimestamp: String
    let data: [KMBRouteStopRecord]

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case generatedTimestamp = "generated_timestamp"
        case data
    }
}

struct KMBRouteStopAPI {

    func fetch(
        route: String,
        direction: String,
        serviceType: String
    ) async throws -> [KMBRouteStopRecord] {

        let urlString =
            "https://data.etabus.gov.hk/v1/transport/kmb/route-stop/" +
            "\(route)/\(direction)/\(serviceType)"

        guard let url = URL(string: urlString) else {
            throw KMBRouteStopAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(
            from: url
        )

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw KMBRouteStopAPIError.invalidResponse
        }

        let decoder = JSONDecoder()

        let responseObject = try decoder.decode(
            KMBRouteStopResponse.self,
            from: data
        )

        return responseObject.data
    }
}

enum KMBRouteStopAPIError: Error {
    case invalidURL
    case invalidResponse
}
