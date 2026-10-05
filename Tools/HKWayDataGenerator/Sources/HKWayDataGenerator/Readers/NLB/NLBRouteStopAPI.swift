//
//  NLBRouteStopAPI.swift
//  HK Way
//

import Foundation

struct NLBRouteStopRecord: Codable, Sendable {

    let stopId: String
    let stopNameTraditional: String
    let stopNameSimplified: String
    let stopNameEnglish: String
    let stopLocationTraditional: String
    let stopLocationSimplified: String
    let stopLocationEnglish: String
    let latitude: String
    let longitude: String

    enum CodingKeys: String, CodingKey {
        case stopId
        case stopNameTraditional = "stopName_c"
        case stopNameSimplified = "stopName_s"
        case stopNameEnglish = "stopName_e"
        case stopLocationTraditional = "stopLocation_c"
        case stopLocationSimplified = "stopLocation_s"
        case stopLocationEnglish = "stopLocation_e"
        case latitude
        case longitude
    }
}

private struct NLBRouteStopResponse: Codable {
    let stops: [NLBRouteStopRecord]
}

struct NLBRouteStopAPI {

    func fetch(
        routeId: String
    ) async throws -> [NLBRouteStopRecord] {

        var components = URLComponents(
            string:
                "https://rt.data.gov.hk/v2/transport/nlb/stop.php"
        )

        components?.queryItems = [
            URLQueryItem(
                name: "action",
                value: "list"
            ),
            URLQueryItem(
                name: "routeId",
                value: routeId
            )
        ]

        guard let url = components?.url else {
            throw NLBRouteStopAPIError.invalidURL
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
            throw NLBRouteStopAPIError.invalidResponse
        }

        return try decode(data)
    }

    func decode(
        _ data: Data
    ) throws -> [NLBRouteStopRecord] {

        try JSONDecoder()
            .decode(
                NLBRouteStopResponse.self,
                from: data
            )
            .stops
    }
}

enum NLBRouteStopAPIError: Error {
    case invalidURL
    case invalidResponse
}
