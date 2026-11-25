import Foundation
import XCTest
@testable import HKWayDataGenerator

@MainActor
final class DatasetFallbackTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    nonisolated private static func stop(_ id: String, name: String = "Fixture", latitude: String = "22.3") -> CTBStopRecord {
        CTBStopRecord(stop: id, nameEnglish: name, nameTraditional: "測試",
                      nameSimplified: "测试", latitude: latitude, longitude: "114.2", dataTimestamp: nil)
    }

    private func historical(_ id: String, operatorID: String = "CTB", age: TimeInterval = 1) -> CTBHistoricalStop {
        CTBHistoricalStop(operatorID: operatorID, observedAt: now.addingTimeInterval(-age), stop: Self.stop(id))
    }

    func testCompleteDatasetUsesCurrentStopAndAllowsPublication() async throws {
        let store = CTBStopHistory(url: nil)
        let result = try await store.resolve("100", now: now) { Self.stop("100") }
        guard case .current(let stop) = result else { return XCTFail("Expected official stop") }
        XCTAssertEqual(stop.stop, "100")
        XCTAssertNoThrow(try DatasetOperatorStage.requirePublishable([true, true, true]))
    }

    func testHTTP200EmptyStopDataIsRejected() {
        let body = Data(#"{"type":"Stop","data":{}}"#.utf8)
        XCTAssertThrowsError(try CTBStopAPI.decode(body, stopId: "100"))
    }

    func testWeeklyExportPreservesProductionFareTimestamp() throws {
        let json = Data(#"{"version":"2026.08.29","generatedAt":"2026-08-29T04:10:48Z","fareDataUpdatedAt":"2026-08-17T23:53:14+08:00"}"#.utf8)
        let baseline = try JSONDecoder().decode(DataVersion.self, from: json)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: output) }
        let data = MasterData(operators: [], routes: [], journeys: [], journeyStops: [],
                              stops: [], schedules: [], operatorStopReferences: [])
        try MasterDataExporter().export(data, to: output, fareDataUpdatedAt: baseline.fareDataUpdatedAt)
        let manifest = try JSONDecoder().decode(
            DataVersion.self, from: Data(contentsOf: output.appendingPathComponent("dataset_info.json"))
        )
        XCTAssertEqual(manifest.fareDataUpdatedAt, baseline.fareDataUpdatedAt)
        XCTAssertNotEqual(manifest.generatedAt, baseline.generatedAt)
    }

    func testExactHistoricalFallback() async throws {
        let store = CTBStopHistory(url: nil, fixtures: ["100": historical("100")])
        let result = try await store.resolve("100", now: now) { throw CTBStopAPIError.invalidResponse }
        guard case .historical(let stop) = result else { return XCTFail("Expected historical stop") }
        XCTAssertEqual(stop.stop, "100")
        XCTAssertThrowsError(try DatasetOperatorStage.requirePublishable([true, false, true]))
    }

    func testMissingStopWithoutHistoryBlocksPublication() async {
        let store = CTBStopHistory(url: nil)
        await assertUnresolved("100", store: store)
        XCTAssertThrowsError(try DatasetOperatorStage.requirePublishable([true, false, true]))
    }

    func testMultipleMissingStopsResolveIndependently() async throws {
        let store = CTBStopHistory(url: nil, fixtures: ["100": historical("100")])
        let first = try await store.resolve("100", now: now) { throw CTBStopAPIError.invalidResponse }
        guard case .historical = first else { return XCTFail("Expected first stop from history") }
        await assertUnresolved("200", store: store)
        await assertUnresolved("300", store: store)
    }

    func testCTBFailureStillRunsNLB() async {
        let failCTB: @Sendable () async throws -> Int = {
            throw CTBStopAPIError.invalidResponse
        }
        let fetchNLB: @Sendable () async throws -> Int = { 123 }
        let ctb = await DatasetOperatorStage.run("CTB fixture", operation: failCTB)
        let nlb = await DatasetOperatorStage.run("NLB fixture", operation: fetchNLB)
        XCTAssertFalse(ctb.complete)
        XCTAssertTrue(nlb.complete)
        XCTAssertEqual(nlb.value, 123)
        XCTAssertThrowsError(try DatasetOperatorStage.requirePublishable([true, ctb.complete, nlb.complete]))
    }

    func testInvalidHistoricalRecordsAreRejected() async {
        let badCoordinates = Self.stop("400", latitude: "NaN")
        let store = CTBStopHistory(url: nil, fixtures: [
            "100": historical("999"),
            "200": historical("200", operatorID: "KMB"),
            "300": historical("300", age: 31 * 86400),
            "400": CTBHistoricalStop(operatorID: "CTB", observedAt: now, stop: badCoordinates)
        ])
        for id in ["100", "200", "300", "400"] {
            await assertUnresolved(id, store: store)
        }
    }

    func testUpstreamRecoverySupersedesHistory() async throws {
        let store = CTBStopHistory(url: nil, fixtures: ["100": historical("100")])
        let result = try await store.resolve("100", now: now) { Self.stop("100", name: "Recovered") }
        guard case .current(let stop) = result else { return XCTFail("Expected current stop") }
        XCTAssertEqual(stop.nameEnglish, "Recovered")
        let recovered = try await store.resolve("100", now: now.addingTimeInterval(1)) {
            throw CTBStopAPIError.invalidResponse
        }
        guard case .historical(let saved) = recovered else { return XCTFail("Expected refreshed history") }
        XCTAssertEqual(saved.nameEnglish, "Recovered")
    }

    private func assertUnresolved(_ id: String, store: CTBStopHistory) async {
        do {
            _ = try await store.resolve(id, now: now) { throw CTBStopAPIError.invalidResponse }
            XCTFail("Expected unresolved stop \(id)")
        } catch {
            XCTAssertTrue(error is CTBStopAPIError)
        }
    }
}
