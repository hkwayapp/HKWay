//
//  GMBETAService.swift
//  HK Way
//

import Foundation

private struct GMBETAResponse: Codable {

    struct Payload: Codable {
        let enabled: Bool
        let eta: [GMBETA]
    }

    let data: Payload
}

struct GMBETAService {

    func fetchETA(
        routeId: String,
        routeSequence: String,
        stopSequence: String
    ) async throws -> [GMBETA] {

        guard let url = URL(
            string:
                "https://data.etagmb.gov.hk/eta/route-stop/\(routeId)/\(routeSequence)/\(stopSequence)"
        ) else {
            throw GMBETAServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw GMBETAServiceError.invalidResponse
        }

        let result = try JSONDecoder().decode(GMBETAResponse.self, from: data)
        return result.data.enabled ? result.data.eta : []
    }
}

enum GMBETAServiceError: Error {
    case invalidURL
    case invalidResponse
}
