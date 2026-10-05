import Foundation

@main
struct TramDatasetChecks {
    static func main() throws {
        let url = URL(fileURLWithPath: "HK Way/Resources/TramRoutes.json")
        let data = try Data(contentsOf: url)
        let dataset = try TramDatasetService.decode(data)

        precondition(dataset.features.count == 427)
        precondition(dataset.routes.map(\.id) == [4001, 4002, 4003, 4004, 4005, 4007])
        precondition(dataset.routes.allSatisfy { !$0.directions.isEmpty })
        precondition(dataset.routes.flatMap(\.directions).allSatisfy { !$0.stops.isEmpty })
        precondition(Set(dataset.features.map(\.properties.lastUpdateDate)) == [
            "2025-05-13T00:00:00",
            "2026-06-24T00:00:00"
        ])

        var bomData = Data([0xEF, 0xBB, 0xBF])
        bomData.append(data)
        let bomDataset = try TramDatasetService.decode(bomData)
        precondition(bomDataset.features.count == 427)

        do {
            _ = try TramDatasetService.decode(Data("{\"type\":\"FeatureCollection\",\"features\":[]}".utf8))
            preconditionFailure("An empty snapshot must fail closed")
        } catch {
            // Expected.
        }

        print("Tram dataset checks passed: bundled routes, stops, BOM and empty-data guard")
    }
}
