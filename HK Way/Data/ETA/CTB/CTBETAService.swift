//
//  CTBETAService.swift
//  HK Way
//
//  Created by Ken on 16/8/2026.
//

import Foundation

private struct CTBETAResponse: Codable {

    let data: [CTBETA]
}

struct CTBETAService {

    func fetchETA(
        stopId: String,
        route: String
    ) async throws -> [CTBETA] {

        guard let url = URL(
            string:
                "https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/CTB/\(stopId)/\(route)"
        ) else {
            throw CTBETAServiceError.invalidURL
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
            throw CTBETAServiceError.invalidResponse
        }

        let result =
            try JSONDecoder().decode(
                CTBETAResponse.self,
                from: data
            )

        return result.data
    }
}

enum CTBETAServiceError: Error {
    case invalidURL
    case invalidResponse
}
