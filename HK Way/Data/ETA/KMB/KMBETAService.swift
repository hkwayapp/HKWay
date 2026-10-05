//
//  KMBETAService.swift
//  HK Way
//
//  Created by Ken on 13/8/2026.
//

import Foundation

enum KMBETAServiceError: Error {
    case invalidURL
    case invalidResponse
}

struct KMBETAService {

    private let baseURL =
        "https://data.etabus.gov.hk/v1/transport/kmb/eta"

    func fetchETA(
        stopId: String,
        route: String,
        serviceType: Int
    ) async throws -> [KMBETA] {

        guard var components = URLComponents(
            string: baseURL
        ) else {
            throw KMBETAServiceError.invalidURL
        }

        components.path +=
            "/\(stopId)/\(route)/\(serviceType)"

        guard let url = components.url else {
            throw KMBETAServiceError.invalidURL
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
            httpResponse.statusCode == 200
        else {
            throw KMBETAServiceError.invalidResponse
        }

        let result =
            try JSONDecoder().decode(
                KMBETAResponse.self,
                from: data
            )

        return result.data
    }
}
