//
//  NLBRouteAPI.swift
//  HK Way
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct NLBRouteRecord: Codable, Sendable {

    let routeId: String
    let routeNumber: String
    let routeNameTraditional: String
    let routeNameSimplified: String
    let routeNameEnglish: String
    let isOvernightRoute: Int
    let isSpecialRoute: Int

    enum CodingKeys: String, CodingKey {
        case routeId
        case routeNumber = "routeNo"
        case routeNameTraditional = "routeName_c"
        case routeNameSimplified = "routeName_s"
        case routeNameEnglish = "routeName_e"
        case isOvernightRoute = "overnightRoute"
        case isSpecialRoute = "specialRoute"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .routeId) {
            routeId = stringID
        } else {
            routeId = String(try container.decode(Int.self, forKey: .routeId))
        }
        routeNumber = try container.decode(String.self, forKey: .routeNumber)
        routeNameTraditional = try container.decode(String.self, forKey: .routeNameTraditional)
        routeNameSimplified = try container.decode(String.self, forKey: .routeNameSimplified)
        routeNameEnglish = try container.decode(String.self, forKey: .routeNameEnglish)
        isOvernightRoute = try container.decode(Int.self, forKey: .isOvernightRoute)
        isSpecialRoute = try container.decode(Int.self, forKey: .isSpecialRoute)
    }
}

private struct NLBRouteListResponse: Codable {
    let routes: [NLBRouteRecord]
}

struct NLBRouteAPI {

    func fetchAll() async throws
        -> [NLBRouteRecord] {

        guard let url = URL(
            string:
                "https://rt.data.gov.hk/v2/transport/nlb/route.php?action=list"
        ) else {
            throw NLBRouteAPIError.invalidURL
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
            throw NLBRouteAPIError.invalidResponse
        }

        return try decode(data)
    }

    func decode(
        _ data: Data
    ) throws -> [NLBRouteRecord] {

        try JSONDecoder()
            .decode(
                NLBRouteListResponse.self,
                from: data
            )
            .routes
    }
}

enum NLBRouteAPIError: Error {
    case invalidURL
    case invalidResponse
}
