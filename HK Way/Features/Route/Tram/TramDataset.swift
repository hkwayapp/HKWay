import Foundation

struct TramDataset: Decodable, Sendable {
    let features: [TramFeature]

    var routes: [TramRoute] {
        Dictionary(grouping: features, by: \.properties.routeId)
            .map { routeId, features in
                TramRoute(id: routeId, features: features)
            }
            .sorted { $0.id < $1.id }
    }
}

struct TramFeature: Decodable, Sendable {
    let geometry: TramGeometry
    let properties: TramStopRecord
}

struct TramGeometry: Decodable, Sendable {
    let coordinates: [Double]
}

struct TramStopRecord: Decodable, Sendable {
    let routeId: Int
    let routeNameC: String
    let routeNameS: String
    let routeNameE: String
    let journeyTime: Int
    let fullFare: Double
    let lastUpdateDate: String
    let routeSeq: Int
    let stopSeq: Int
    let stopId: Int
    let stopNameC: String
    let stopNameS: String
    let stopNameE: String
}

struct TramRoute: Identifiable, Sendable {
    let id: Int
    let directions: [TramDirection]
    let nameEnglish: String
    let nameTraditional: String
    let nameSimplified: String
    let fare: Double
    let lastUpdateDate: String

    init(id: Int, features: [TramFeature]) {
        self.id = id

        let first = features[0].properties
        nameEnglish = first.routeNameE
        nameTraditional = first.routeNameC
        nameSimplified = first.routeNameS
        fare = first.fullFare
        lastUpdateDate = first.lastUpdateDate

        directions = Dictionary(
            grouping: features,
            by: \.properties.routeSeq
        )
        .map { sequence, features in
            TramDirection(
                id: sequence,
                journeyTime: features[0].properties.journeyTime,
                stops: features
                    .sorted {
                        $0.properties.stopSeq < $1.properties.stopSeq
                    }
                    .map { TramStop(feature: $0) }
            )
        }
        .sorted { $0.id < $1.id }
    }

    func name(for language: TransitLanguage) -> String {
        switch language {
        case .english: nameEnglish
        case .traditionalChinese: nameTraditional
        case .simplifiedChinese: nameSimplified
        }
    }
}

struct TramDirection: Identifiable, Sendable {
    let id: Int
    let journeyTime: Int
    let stops: [TramStop]

    func destination(for language: TransitLanguage) -> String {
        stops.last?.name(for: language) ?? ""
    }
}

struct TramStop: Identifiable, Sendable {
    let id: Int
    let sequence: Int
    let nameEnglish: String
    let nameTraditional: String
    let nameSimplified: String
    let latitude: Double
    let longitude: Double

    init(feature: TramFeature) {
        let properties = feature.properties
        id = properties.stopId
        sequence = properties.stopSeq
        nameEnglish = properties.stopNameE
        nameTraditional = properties.stopNameC
        nameSimplified = properties.stopNameS
        longitude = feature.geometry.coordinates.first ?? 0
        latitude = feature.geometry.coordinates.dropFirst().first ?? 0
    }

    func name(for language: TransitLanguage) -> String {
        switch language {
        case .english: nameEnglish
        case .traditionalChinese: nameTraditional
        case .simplifiedChinese: nameSimplified
        }
    }
}

@MainActor
enum TramDatasetService {
    private static var cachedDataset: TramDataset?

    private static let bundledResourceName = "TramRoutes"
    private static let cachedFileName = "TramRoutes.json"

    private static let datasetURL = URL(
        string: "https://static.data.gov.hk/td/routes-fares-geojson/JSON_TRAM.json"
    )!

    static func loadOffline() throws -> TramDataset {
        if let cachedDataset {
            return cachedDataset
        }

        if let saved = try? decode(Data(contentsOf: cacheURL())) {
            cachedDataset = saved
            return saved
        }

        guard let bundledURL = Bundle.main.url(
            forResource: bundledResourceName,
            withExtension: "json"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let bundled = try decode(Data(contentsOf: bundledURL))
        cachedDataset = bundled
        return bundled
    }

    static func refresh() async throws -> TramDataset {
        let (data, response) = try await URLSession.shared.data(from: datasetURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let dataset = try decode(data)
        try? save(data)
        cachedDataset = dataset
        return dataset
    }

    static func decode(_ data: Data) throws -> TramDataset {
        let normalizedData: Data
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            normalizedData = Data(data.dropFirst(3))
        } else {
            normalizedData = data
        }

        let dataset = try JSONDecoder().decode(
            TramDataset.self,
            from: normalizedData
        )

        guard !dataset.features.isEmpty, !dataset.routes.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return dataset
    }

    private static func cacheURL() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent(
            "TramData",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(cachedFileName)
    }

    private static func save(_ data: Data) throws {
        try data.write(to: cacheURL(), options: .atomic)
    }
}
