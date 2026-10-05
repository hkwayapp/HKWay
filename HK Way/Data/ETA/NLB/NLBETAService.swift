//
//  NLBETAService.swift
//  HK Way
//

import Foundation

enum NLBETAServiceError: Error {
    case invalidURL
    case invalidResponse
}

struct NLBETAService {

    private let baseURL =
        "https://rt.data.gov.hk/v2/transport/nlb/stop.php"

    func fetchETA(
        routeId: String,
        stopId: String,
        language: String = "en"
    ) async throws -> [NLBETA] {

        guard var components = URLComponents(
            string: baseURL
        ) else {
            throw NLBETAServiceError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(
                name: "action",
                value: "estimatedArrivals"
            ),
            URLQueryItem(
                name: "routeId",
                value: routeId
            ),
            URLQueryItem(
                name: "stopId",
                value: stopId
            ),
            URLQueryItem(
                name: "language",
                value: language
            )
        ]

        guard let url = components.url else {
            throw NLBETAServiceError.invalidURL
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )

        request.httpMethod = "GET"

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse,
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw NLBETAServiceError.invalidResponse
        }

        let result = try JSONDecoder().decode(
            NLBETAResponse.self,
            from: data
        )

        return result.estimatedArrivals ?? []
    }
}
