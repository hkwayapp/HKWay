//
//  CSDIBusRouteShapeReader.swift
//  HK Way
//

import Foundation

struct CSDIBusRouteShape: Equatable {
    let routeId: String
    let routeSequence: Int
    let companyCode: String
    let routeName: String
    let segments: [[JourneyShapeCoordinate]]
}

enum CSDIBusRouteShapeReaderError: Error {
    case invalidURL
    case invalidResponse
    case unsupportedGeometry(String)
    case invalidCoordinate
}

struct CSDIBusRouteShapeReader {

    private let endpoint =
        "https://portal.csdi.gov.hk/server/rest/services/common/td_rcd_1638844988873_41214/FeatureServer/0/query"

    func fetch(
        pageSize: Int = 100
    ) async throws -> [CSDIBusRouteShape] {

        let featureCount = try await fetchFeatureCount()
        let offsets = Array(
            stride(
                from: 0,
                to: featureCount,
                by: pageSize
            )
        )
        var results: [CSDIBusRouteShape] = []

        for batchStart in stride(
            from: 0,
            to: offsets.count,
            by: 4
        ) {
            let batchEnd = min(
                batchStart + 4,
                offsets.count
            )
            let batch = offsets[
                batchStart..<batchEnd
            ]

            let pages = try await
                withThrowingTaskGroup(
                    of: (Int, [CSDIBusRouteShape]).self
                ) { group in

                    for offset in batch {
                        group.addTask {
                            (
                                offset,
                                try await fetchPage(
                                    resultOffset: offset,
                                    resultRecordCount:
                                        pageSize
                                )
                            )
                        }
                    }

                    var pages:
                        [(Int, [CSDIBusRouteShape])] = []

                    for try await page in group {
                        pages.append(page)
                    }

                    return pages.sorted {
                        $0.0 < $1.0
                    }
                }

            for page in pages {
                results.append(
                    contentsOf: page.1
                )
            }
        }

        return results
    }

    func countURL() throws -> URL {

        guard var components = URLComponents(
            string: endpoint
        ) else {
            throw CSDIBusRouteShapeReaderError
                .invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(
                name: "returnCountOnly",
                value: "true"
            ),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = components.url else {
            throw CSDIBusRouteShapeReaderError
                .invalidURL
        }

        return url
    }

    func requestURL(
        resultOffset: Int,
        resultRecordCount: Int
    ) throws -> URL {

        guard var components = URLComponents(
            string: endpoint
        ) else {
            throw CSDIBusRouteShapeReaderError
                .invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(
                name: "outFields",
                value:
                    "ROUTE_ID,ROUTE_SEQ,COMPANY_CODE,ROUTE_NAMEE"
            ),
            URLQueryItem(
                name: "returnGeometry",
                value: "true"
            ),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(
                name: "resultOffset",
                value: String(resultOffset)
            ),
            URLQueryItem(
                name: "resultRecordCount",
                value: String(resultRecordCount)
            ),
            URLQueryItem(
                name: "orderByFields",
                value: "OBJECTID ASC"
            ),
            URLQueryItem(
                name: "maxAllowableOffset",
                value: "0.000005"
            ),
            URLQueryItem(
                name: "geometryPrecision",
                value: "6"
            )
        ]

        guard let url = components.url else {
            throw CSDIBusRouteShapeReaderError
                .invalidURL
        }

        return url
    }

    private func fetchFeatureCount() async throws
        -> Int {

        let (data, response) = try await request(
            url: countURL()
        )

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw CSDIBusRouteShapeReaderError
                .invalidResponse
        }

        return try JSONDecoder().decode(
            FeatureCount.self,
            from: data
        ).count
    }

    private func fetchPage(
        resultOffset: Int,
        resultRecordCount: Int
    ) async throws -> [CSDIBusRouteShape] {

        let url = try requestURL(
            resultOffset: resultOffset,
            resultRecordCount: resultRecordCount
        )

        var lastError: Error?

        for attempt in 1...3 {
            do {
                let (data, response) = try await request(
                    url: url
                )

                guard
                    let httpResponse =
                        response as? HTTPURLResponse,
                    (200...299).contains(
                        httpResponse.statusCode
                    )
                else {
                    throw CSDIBusRouteShapeReaderError
                        .invalidResponse
                }

                return try decode(data)
            } catch {
                lastError = error

                if attempt == 3 {
                    throw error
                }
            }
        }

        throw lastError ??
            CSDIBusRouteShapeReaderError.invalidResponse
    }

    private func request(
        url: URL
    ) async throws -> (Data, URLResponse) {

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 60
        )
        request.setValue(
            "no-cache",
            forHTTPHeaderField: "Cache-Control"
        )

        return try await URLSession.shared.data(
            for: request
        )
    }

    func decode(
        _ data: Data
    ) throws -> [CSDIBusRouteShape] {

        let collection = try JSONDecoder().decode(
            FeatureCollection.self,
            from: data
        )

        return try collection.features.map { feature in
            CSDIBusRouteShape(
                routeId: String(
                    feature.properties.routeId
                ),
                routeSequence:
                    feature.properties.routeSequence,
                companyCode:
                    feature.properties.companyCode,
                routeName:
                    feature.properties.routeName,
                segments: try feature.geometry
                    .journeyShapeSegments()
            )
        }
    }
}

private struct FeatureCount: Decodable {
    let count: Int
}

private struct FeatureCollection: Decodable {
    let features: [Feature]
}

private struct Feature: Decodable {
    let geometry: Geometry
    let properties: Properties
}

private struct Properties: Decodable {
    let routeId: Int
    let routeSequence: Int
    let companyCode: String
    let routeName: String

    enum CodingKeys: String, CodingKey {
        case routeId = "ROUTE_ID"
        case routeSequence = "ROUTE_SEQ"
        case companyCode = "COMPANY_CODE"
        case routeName = "ROUTE_NAMEE"
    }
}

private struct Geometry: Decodable {
    let type: String
    let lineString: [[Double]]?
    let multiLineString: [[[Double]]]?

    enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        type = try container.decode(
            String.self,
            forKey: .type
        )

        switch type {
        case "LineString":
            lineString = try container.decode(
                [[Double]].self,
                forKey: .coordinates
            )
            multiLineString = nil

        case "MultiLineString":
            lineString = nil
            multiLineString = try container.decode(
                [[[Double]]].self,
                forKey: .coordinates
            )

        default:
            throw CSDIBusRouteShapeReaderError
                .unsupportedGeometry(type)
        }
    }

    func journeyShapeSegments() throws
        -> [[JourneyShapeCoordinate]] {

        let rawSegments: [[[Double]]]

        if let lineString {
            rawSegments = [lineString]
        } else {
            rawSegments = multiLineString ?? []
        }

        return try rawSegments.map { segment in
            try segment.map { coordinate in
                guard coordinate.count >= 2 else {
                    throw CSDIBusRouteShapeReaderError
                        .invalidCoordinate
                }

                return JourneyShapeCoordinate(
                    latitude: coordinate[1],
                    longitude: coordinate[0]
                )
            }
        }
    }
}
