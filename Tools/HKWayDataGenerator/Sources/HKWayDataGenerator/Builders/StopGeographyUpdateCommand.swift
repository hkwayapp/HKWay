import Foundation

struct StopGeographyUpdateResult {
    let stopCount: Int
    let classifiedStopCount: Int
    let unclassifiedStopCount: Int
    let outputURL: URL
    let version: DataVersion
}

struct StopGeographyUpdateCommand {
    func run(in rootDirectory: URL) async throws
        -> StopGeographyUpdateResult {
        let sourceURL = rootDirectory
            .appendingPathComponent("Dataset")
            .appendingPathComponent("stops.json")

        let sourceData = try Data(contentsOf: sourceURL)
        let stops = try JSONDecoder().decode(
            [Stop].self,
            from: sourceData
        )

        let boundaries = try await DistrictBoundaryClient().fetch()
        let enrichedStops = StopGeographyEnricher(
            boundaries: boundaries
        ).enrich(stops)

        let outputDirectory = rootDirectory
            .appendingPathComponent("GeographyUpdate")
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let outputURL = outputDirectory
            .appendingPathComponent("stops.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(enrichedStops).write(to: outputURL)

        let metadataURL = rootDirectory
            .appendingPathComponent("Dataset")
            .appendingPathComponent("dataset_info.json")
        let currentVersion = try JSONDecoder().decode(
            DataVersion.self,
            from: Data(contentsOf: metadataURL)
        )
        let now = Date()
        let version = DataVersion(
            version: nextVersion(
                after: currentVersion.version,
                generatedAt: now
            ),
            generatedAt: ISO8601DateFormatter().string(from: now),
            fareDataUpdatedAt: currentVersion.fareDataUpdatedAt
        )
        try encoder.encode(version).write(
            to: outputDirectory.appendingPathComponent(
                "dataset_info.json"
            ),
            options: .atomic
        )

        let classifiedStopCount = enrichedStops.filter {
            $0.regionId != nil && $0.districtId != nil
        }.count

        return StopGeographyUpdateResult(
            stopCount: enrichedStops.count,
            classifiedStopCount: classifiedStopCount,
            unclassifiedStopCount:
                enrichedStops.count - classifiedStopCount,
            outputURL: outputURL,
            version: version
        )
    }

    private func nextVersion(
        after currentVersion: String,
        generatedAt: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateVersion = formatter.string(from: generatedAt)

        guard currentVersion == dateVersion ||
            currentVersion.hasPrefix(dateVersion + ".")
        else {
            return dateVersion
        }

        let revision = currentVersion
            .split(separator: ".")
            .dropFirst(3)
            .first
            .flatMap { Int($0) } ?? 0

        return dateVersion + "." + String(revision + 1)
    }
}
