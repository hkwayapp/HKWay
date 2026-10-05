//
//  MTRBusETAService.swift
//  HK Way
//

import Foundation

enum MTRBusETAServiceError: Error {
    case invalidURL
    case invalidResponse
}

struct MTRBusETAService {

    private let endpoint =
        "https://rt.data.gov.hk/v1/transport/mtr/bus/getSchedule"

    func fetchETA(
        routeName: String,
        language: String = "en"
    ) async throws -> MTRBusETAResponse {

        guard let url = URL(string: endpoint) else {
            throw MTRBusETAServiceError.invalidURL
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "language": language,
                "routeName": routeName
            ]
        )

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
            throw MTRBusETAServiceError.invalidResponse
        }

        return try JSONDecoder().decode(
            MTRBusETAResponse.self,
            from: data
        )
    }
}
