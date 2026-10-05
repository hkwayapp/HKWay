import Foundation

struct DistrictBoundary: Sendable {
    let id: String
    let nameEnglish: String
    let nameTraditional: String
    let polygons: [[[[Double]]]]

    var regionId: String? {
        switch id {
        case "A", "B", "C", "D":
            "hki"
        case "E", "F", "G", "H", "J":
            "kln"
        case "K", "L", "M", "N", "P", "Q", "R", "S", "T":
            "nt"
        default:
            nil
        }
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        polygons.contains { polygon in
            guard let exteriorRing = polygon.first else {
                return false
            }

            guard contains(
                latitude: latitude,
                longitude: longitude,
                ring: exteriorRing
            ) else {
                return false
            }

            return !polygon.dropFirst().contains { hole in
                contains(
                    latitude: latitude,
                    longitude: longitude,
                    ring: hole
                )
            }
        }
    }

    private func contains(
        latitude: Double,
        longitude: Double,
        ring: [[Double]]
    ) -> Bool {
        guard ring.count >= 3 else {
            return false
        }

        var isInside = false
        var previousIndex = ring.count - 1

        for currentIndex in ring.indices {
            let current = ring[currentIndex]
            let previous = ring[previousIndex]

            guard current.count >= 2, previous.count >= 2 else {
                previousIndex = currentIndex
                continue
            }

            let currentLongitude = current[0]
            let currentLatitude = current[1]
            let previousLongitude = previous[0]
            let previousLatitude = previous[1]

            let crossesLatitude =
                (currentLatitude > latitude)
                != (previousLatitude > latitude)

            if crossesLatitude {
                let intersectionLongitude =
                    (previousLongitude - currentLongitude)
                    * (latitude - currentLatitude)
                    / (previousLatitude - currentLatitude)
                    + currentLongitude

                if longitude < intersectionLongitude {
                    isInside.toggle()
                }
            }

            previousIndex = currentIndex
        }

        return isInside
    }
}

struct DistrictBoundaryClient {
    private let url = URL(
        string: "https://www.had.gov.hk/psi/hong-kong-administrative-boundaries/hksar_18_district_boundary.json"
    )!

    func fetch() async throws -> [DistrictBoundary] {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let collection = try JSONDecoder().decode(
            DistrictFeatureCollection.self,
            from: data
        )

        return collection.features.map { feature in
            DistrictBoundary(
                id: feature.properties.id,
                nameEnglish: feature.properties.nameEnglish,
                nameTraditional: feature.properties.nameTraditional,
                polygons: feature.geometry.polygons
            )
        }
    }
}

private struct DistrictFeatureCollection: Decodable {
    let features: [DistrictFeature]
}

private struct DistrictFeature: Decodable {
    let geometry: DistrictGeometry
    let properties: DistrictProperties
}

private struct DistrictProperties: Decodable {
    let id: String
    let nameEnglish: String
    let nameTraditional: String

    enum CodingKeys: String, CodingKey {
        case id = "地區號碼"
        case nameEnglish = "District"
        case nameTraditional = "地區"
    }
}

private struct DistrictGeometry: Decodable {
    let polygons: [[[[Double]]]]

    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "Polygon":
            polygons = [
                try container.decode(
                    [[[Double]]].self,
                    forKey: .coordinates
                )
            ]
        case "MultiPolygon":
            polygons = try container.decode(
                [[[[Double]]]].self,
                forKey: .coordinates
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported district geometry: \(type)"
            )
        }
    }
}
