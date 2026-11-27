//
//  KMBRouteStopAPI.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct KMBRouteStopRecord: Codable, Sendable, Equatable {

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

        return try await download(url, label: "KMB reference route-stop")
    }

    func fetchAll() async throws -> [KMBRouteStopRecord] {
        guard let url = URL(string: "https://data.etabus.gov.hk/v1/transport/kmb/route-stop") else {
            throw KMBRouteStopAPIError.invalidURL
        }
        return try await download(url, label: "KMB bulk route-stop")
    }

    private func download(_ url: URL, label: String) async throws -> [KMBRouteStopRecord] {
        let (data, _) = try await KMBTiming.download(url, label: label)
        return try KMBTiming.measure("\(label) decoding") { try Self.decode(data) }
    }

    static func decode(_ data: Data) throws -> [KMBRouteStopRecord] {
        let response = try JSONDecoder().decode(KMBRouteStopResponse.self, from: data)
        guard !response.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !response.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ISO8601DateFormatter().date(from: response.generatedTimestamp) != nil,
              !response.data.isEmpty else { throw KMBRouteStopAPIError.invalidResponse }
        return response.data
    }
}

enum KMBRouteStopAPIError: Error {
    case invalidURL
    case invalidResponse
}
