import Foundation

struct SmartSearchCommunity: Identifiable, Hashable {
    struct Coordinate: Codable, Hashable {
        let longitude: Double
        let latitude: Double

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            longitude = try container.decode(Double.self)
            latitude = try container.decode(Double.self)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(longitude)
            try container.encode(latitude)
        }
    }

    let id: String
    let districtId: String
    let nameEnglish: String
    let nameTraditional: String
    let rings: [[Coordinate]]

    func title(for language: TransitLanguage) -> String {
        switch language {
        case .english:
            nameEnglish
        case .traditionalChinese:
            "\(nameTraditional)  \(nameEnglish)"
        case .simplifiedChinese:
            "\(nameSimplified)  \(nameEnglish)"
        }
    }

    func matches(stop: StopEntity?) -> Bool {
        guard let stop,
              stop.districtId == districtId
        else {
            return false
        }

        var isInside = false

        for ring in rings where contains(
            latitude: stop.latitude,
            longitude: stop.longitude,
            in: ring
        ) {
            isInside.toggle()
        }

        return isInside
    }

    private var nameSimplified: String {
        let replacements: [Character: Character] = [
            "區": "区", "灣": "湾", "門": "门", "東": "东",
            "鄉": "乡", "圍": "围", "廈": "厦", "長": "长",
            "將": "将", "軍": "军", "紅": "红", "龍": "龙",
            "馬": "马", "頭": "头", "樂": "乐", "綫": "线",
            "嶺": "岭", "華": "华", "廣": "广", "島": "岛"
        ]

        return String(nameTraditional.map { replacements[$0] ?? $0 })
    }

    private func contains(
        latitude: Double,
        longitude: Double,
        in ring: [Coordinate]
    ) -> Bool {
        guard ring.count > 2 else {
            return false
        }

        var isInside = false
        var previousIndex = ring.count - 1

        for currentIndex in ring.indices {
            let current = ring[currentIndex]
            let previous = ring[previousIndex]
            let crossesLatitude =
                (current.latitude > latitude)
                != (previous.latitude > latitude)

            if crossesLatitude {
                let boundaryLongitude =
                    (previous.longitude - current.longitude)
                    * (latitude - current.latitude)
                    / (previous.latitude - current.latitude)
                    + current.longitude

                if longitude < boundaryLongitude {
                    isInside.toggle()
                }
            }

            previousIndex = currentIndex
        }

        return isInside
    }
}

enum SmartSearchCommunityCatalog {
    private struct FeatureCollection: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let properties: Properties
        let geometry: Geometry
    }

    private struct Properties: Decodable {
        let code: String
        let nameEnglish: String
        let nameTraditional: String
        let districtId: String

        enum CodingKeys: String, CodingKey {
            case code = "DCGCCODE"
            case nameEnglish = "ENAME"
            case nameTraditional = "CNAME"
            case districtId = "DISTRICT_CODE"
        }
    }

    private struct Geometry: Decodable {
        let coordinates: [[SmartSearchCommunity.Coordinate]]
    }

    static let all: [SmartSearchCommunity] = {
        guard let url = Bundle.main.url(
            forResource: "SmartSearchCommunities",
            withExtension: "geojson"
        ),
        let data = try? Data(contentsOf: url),
        let collection = try? JSONDecoder().decode(
            FeatureCollection.self,
            from: data
        ) else {
            return []
        }

        return collection.features.map { feature in
            SmartSearchCommunity(
                id: feature.properties.code,
                districtId: feature.properties.districtId,
                nameEnglish: feature.properties.nameEnglish,
                nameTraditional: feature.properties.nameTraditional,
                rings: feature.geometry.coordinates
            )
        }
    }()

    static func communities(in districtId: String) -> [SmartSearchCommunity] {
        all.filter { $0.districtId == districtId }
    }

    static func community(
        containing stop: StopEntity?
    ) -> SmartSearchCommunity? {
        guard let districtId = stop?.districtId else {
            return nil
        }

        return communities(in: districtId).first { $0.matches(stop: stop) }
    }
}
