//
//  NLBRouteStopAPI.swift
//  HK Way
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .stopId) {
            stopId = stringID
        } else {
            stopId = String(try container.decode(Int.self, forKey: .stopId))
        }
        stopNameTraditional = try container.decode(String.self, forKey: .stopNameTraditional)
        stopNameSimplified = try container.decode(String.self, forKey: .stopNameSimplified)
        stopNameEnglish = try container.decode(String.self, forKey: .stopNameEnglish)
        stopLocationTraditional = try container.decode(String.self, forKey: .stopLocationTraditional)
        stopLocationSimplified = try container.decode(String.self, forKey: .stopLocationSimplified)
        stopLocationEnglish = try container.decode(String.self, forKey: .stopLocationEnglish)
        latitude = try container.decode(String.self, forKey: .latitude)
        longitude = try container.decode(String.self, forKey: .longitude)
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
            try await DatasetHTTP.data(
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
