import Foundation

enum OperatorDatasetUnit: String, Codable, CaseIterable {
    case kmbLwb = "KMB-LWB"
    case ctb = "CTB"
    case nlb = "NLB"
    case gmb = "GMB"
    case feeder = "LRTFeeder"

    var operators: Set<String> {
        self == .kmbLwb ? ["KMB", "LWB"] : [rawValue]
    }
}

struct DatasetSourceProvenance: Codable {
    let name: String
    var sourceTimestamp: String? = nil
    var retrievedAt: String? = nil
}

struct OperatorBaselineDependency: Codable, Equatable {
    let identity: String
    let sha256: String
}

struct SharedTDBaselineManifest: Codable {
    let schemaVersion: Int
    let dependency: OperatorBaselineDependency
    let productionVersion: String
    let sourceProvenance: [DatasetSourceProvenance]
    let recordCounts: [String: Int]
    let fareDataUpdatedAt: String
}

struct ShardReferencePosition: Codable, Hashable {
    let operatorId: String
    let journeyId: String
    let sequence: Int

    init(_ reference: OperatorStopReference) {
        operatorId = reference.operatorId
        journeyId = reference.journeyId
        sequence = reference.sequence
    }
}

struct SharedTDBaselinePayload: Codable {
    let topology: MasterData
    let journeyShapes: [JourneyShape]
    let requiredReferencePositions: [ShardReferencePosition]
    let metadata: DataVersion

    var counts: [String: Int] {
        [
            "operators": topology.operators.count, "routes": topology.routes.count, "journeys": topology.journeys.count,
            "journeyStops": topology.journeyStops.count, "stops": topology.stops.count, "schedules": topology.schedules.count,
            "journeyShapes": journeyShapes.count, "requiredReferencePositions": requiredReferencePositions.count,
            "fullFares": topology.journeys.filter { $0.adultFullFareCents != nil }.count,
            "sectionFareTiers": topology.journeys.reduce(0) { $0 + ($1.sectionFareTiers?.count ?? 0) },
            "districtClassifiedStops": topology.stops.filter { $0.districtId != nil }.count
        ]
    }
}

struct OperatorShardManifest: Codable {
    let schemaVersion: Int
    let unit: OperatorDatasetUnit
    let operatorIDs: [String]
    let version: String
    let requiredBaseline: OperatorBaselineDependency
    let sources: [DatasetSourceProvenance]
    let validatedAt: String
    let recordCounts: [String: Int]
    let payloadSHA256: String
    let fareDataUpdatedAt: String
}

struct OperatorDatasetRegistry: Codable {
    let schemaVersion: Int
    let requiredBaseline: OperatorBaselineDependency
    var latest: [String: String]
}

struct OperatorShardStaging {
    let root: URL
    private static let schemaVersion = 1

    func stageBaseline(_ production: ProductionDatasetSnapshot, sources: [DatasetSourceProvenance]? = nil) throws -> SharedTDBaselineManifest {
        _ = try ProductionDatasetPreservation(baseline: production)
        guard let fareDate = production.metadata.fareDataUpdatedAt,
              Self.isSafeComponent(production.metadata.version) else {
            throw failure("Invalid source version or fare metadata.")
        }
        let payload = Self.baselinePayload(production)
        let bytes = try Self.encode(payload)
        let sha = try Self.digest(bytes)
        let dependency = OperatorBaselineDependency(identity: "td-\(production.metadata.version)-\(sha)", sha256: sha)
        let provenance = sources ?? [.init(name: "Verified legacy production snapshot \(production.metadata.version)",
                                             sourceTimestamp: production.metadata.generatedAt)]
        guard Self.validSources(provenance) else { throw failure("Invalid or missing TD source provenance.") }
        let manifest = SharedTDBaselineManifest(
            schemaVersion: Self.schemaVersion, dependency: dependency, productionVersion: production.metadata.version,
            sourceProvenance: provenance,
            recordCounts: payload.counts, fareDataUpdatedAt: fareDate
        )
        let destination = baselineDirectory(dependency.identity)
        if FileManager.default.fileExists(atPath: destination.path) {
            return try loadBaseline(dependency.identity).0
        }
        try Self.stageDirectory(destination, files: [
            "topology.json": bytes, "manifest.json": Self.encode(manifest)
        ])
        return manifest
    }

    private static func baselinePayload(_ production: ProductionDatasetSnapshot) -> SharedTDBaselinePayload {
        let data = production.data
        return SharedTDBaselinePayload(
            topology: .init(operators: data.operators, routes: data.routes, journeys: data.journeys,
                            journeyStops: data.journeyStops, stops: data.stops, schedules: data.schedules,
                            operatorStopReferences: []),
            journeyShapes: production.shapes,
            requiredReferencePositions: Self.ordered(data.operatorStopReferences).map(ShardReferencePosition.init),
            metadata: production.metadata
        )
    }

    func legacyInputs(baselineID: String, verifiedProduction: ProductionDatasetSnapshot) throws
        -> (SharedTDBaselinePayload, [OperatorStopReference]) {
        let (baseline, payload) = try loadBaseline(baselineID)
        let expectedHash = try Self.digest(Self.encode(Self.baselinePayload(verifiedProduction)))
        guard expectedHash == baseline.dependency.sha256 else {
            throw failure("Registry TD baseline does not match the verified legacy snapshot.")
        }
        let registry = try readRegistry(dependency: baseline.dependency)
        let units = OperatorDatasetUnit.allCases
        let expected = Set(units.map(\.rawValue))
        guard Set(registry.latest.keys) == expected,
              Set(registry.latest.values).count == units.count else {
            throw failure("Legacy composition requires exactly one distinct shard for every operator unit.")
        }
        let references = try units.flatMap { unit -> [OperatorStopReference] in
            guard let version = registry.latest[unit.rawValue] else {
                throw failure("Missing shard for \(unit.rawValue).")
            }
            return try readShard(unit, version: version, baseline: baseline, payload: payload).references
        }
        return (payload, references)
    }

    func loadBaseline(_ identity: String) throws -> (SharedTDBaselineManifest, SharedTDBaselinePayload) {
        guard Self.isSafeComponent(identity) else { throw failure("Invalid baseline identifier.") }
        let path = baselineDirectory(identity)
        let manifest: SharedTDBaselineManifest = try Self.read("manifest.json", in: path)
        let bytes = try Data(contentsOf: path.appendingPathComponent("topology.json"))
        let hash = try Self.digest(bytes)
        let payload = try JSONDecoder().decode(SharedTDBaselinePayload.self, from: bytes)
        guard manifest.schemaVersion == Self.schemaVersion,
              manifest.dependency == .init(identity: identity, sha256: hash),
              identity == "td-\(payload.metadata.version)-\(hash)",
              manifest.productionVersion == payload.metadata.version,
              manifest.recordCounts == payload.counts,
              manifest.fareDataUpdatedAt == payload.metadata.fareDataUpdatedAt,
              payload.topology.operatorStopReferences.isEmpty else {
            throw failure("Baseline dependency, metadata or checksum mismatch.")
        }
        try Topology(payload.topology).validate(shapes: payload.journeyShapes)
        return (manifest, payload)
    }

    func validateGeneratedReferences(_ rows: [OperatorStopReference], unit: OperatorDatasetUnit,
                                     baseline: SharedTDBaselinePayload) throws {
        try validate(rows: rows, unit: unit, payload: baseline)
    }

    /// Returns the existing manifest for byte-identical references on the same baseline.
    /// Failed operators leave the registry untouched by omitting their registration.
    func register(unit: OperatorDatasetUnit, references: [OperatorStopReference],
                  baselineID: String, sources: [DatasetSourceProvenance], now: Date = .now) throws -> OperatorShardManifest {
        let (baseline, payload) = try loadBaseline(baselineID)
        guard Self.validSources(sources) else { throw failure("Invalid or missing source provenance.") }
        let rows = Self.ordered(references)
        try validate(rows: rows, unit: unit, payload: payload)
        let bytes = try Self.encode(rows)
        let hash = try Self.digest(bytes)
        let version = "\(baseline.dependency.identity)-\(hash)"
        let lock = root.appendingPathComponent(".registry-lock")
        try FileManager.default.createDirectory(at: lock, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: lock) }
        var registry = try readRegistry(dependency: baseline.dependency)
        if let previous = registry.latest[unit.rawValue] {
            _ = try readShard(unit, version: previous, baseline: baseline, payload: payload)
        }

        let directory = shardDirectory(unit, version: version)
        let manifest: OperatorShardManifest
        if FileManager.default.fileExists(atPath: directory.path) {
            if let current = registry.latest[unit.rawValue], current != version {
                throw failure("Historical shard content for \(unit.rawValue) cannot replace the current version implicitly.")
            }
            manifest = try readShard(unit, version: version, baseline: baseline, payload: payload).manifest
        } else {
            manifest = .init(
                schemaVersion: Self.schemaVersion, unit: unit, operatorIDs: unit.operators.sorted(),
                version: version, requiredBaseline: baseline.dependency, sources: sources,
                validatedAt: ISO8601DateFormatter().string(from: now),
                recordCounts: Self.counts(rows), payloadSHA256: hash,
                fareDataUpdatedAt: baseline.fareDataUpdatedAt
            )
            try Self.stageDirectory(directory, files: [
                "references.json": bytes, "manifest.json": Self.encode(manifest)
            ])
        }
        if registry.latest[unit.rawValue] != version {
            registry.latest[unit.rawValue] = version
            try Self.encode(registry).write(to: root.appendingPathComponent("registry.json"), options: .atomic)
        }
        return manifest
    }

    func validateRegistry(baselineID: String) throws -> OperatorDatasetRegistry {
        let (baseline, payload) = try loadBaseline(baselineID)
        let registry = try readRegistry(dependency: baseline.dependency)
        for (key, version) in registry.latest {
            guard let unit = OperatorDatasetUnit(rawValue: key) else { throw failure("Unknown registry unit \(key).") }
            _ = try readShard(unit, version: version, baseline: baseline, payload: payload)
        }
        return registry
    }

    private func readRegistry(dependency: OperatorBaselineDependency) throws -> OperatorDatasetRegistry {
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("registry.json").path) else {
            return .init(schemaVersion: Self.schemaVersion, requiredBaseline: dependency, latest: [:])
        }
        let bytes = try Data(contentsOf: root.appendingPathComponent("registry.json"))
        let registry = try JSONDecoder().decode(OperatorDatasetRegistry.self, from: bytes)
        // Canonical encoding also rejects duplicate JSON keys dropped by the decoder.
        guard try Self.encode(registry) == bytes else { throw failure("Invalid registry encoding or duplicate registry entry.") }
        guard registry.schemaVersion == Self.schemaVersion, registry.requiredBaseline == dependency else {
            throw failure("Registry is pinned to a different TD baseline; use a separate staging registry.")
        }
        return registry
    }

    private func readShard(_ unit: OperatorDatasetUnit, version: String, baseline: SharedTDBaselineManifest,
                           payload: SharedTDBaselinePayload) throws -> (manifest: OperatorShardManifest, references: [OperatorStopReference]) {
        guard Self.isSafeComponent(version) else { throw failure("Invalid shard version.") }
        let path = shardDirectory(unit, version: version)
        let manifest: OperatorShardManifest = try Self.read("manifest.json", in: path)
        let bytes = try Data(contentsOf: path.appendingPathComponent("references.json"))
        let hash = try Self.digest(bytes)
        guard manifest.schemaVersion == Self.schemaVersion, manifest.unit == unit,
              manifest.operatorIDs == unit.operators.sorted(), manifest.version == version,
              manifest.requiredBaseline == baseline.dependency, manifest.payloadSHA256 == hash,
              version == "\(baseline.dependency.identity)-\(hash)",
              manifest.fareDataUpdatedAt == baseline.fareDataUpdatedAt,
              ISO8601DateFormatter().date(from: manifest.validatedAt) != nil,
              Self.validSources(manifest.sources) else {
            throw failure("Shard \(unit.rawValue) dependency, metadata or checksum mismatch.")
        }
        let rows = try JSONDecoder().decode([OperatorStopReference].self, from: bytes)
        guard manifest.recordCounts == Self.counts(rows) else { throw failure("Shard record counts differ.") }
        try validate(rows: rows, unit: unit, payload: payload)
        return (manifest, rows)
    }

    private func validate(rows: [OperatorStopReference], unit: OperatorDatasetUnit,
                          payload: SharedTDBaselinePayload) throws {
        guard Set(rows.map(\.operatorId)) == unit.operators else {
            throw failure("Incomplete or mixed operator membership for \(unit.rawValue).")
        }
        try Topology(payload.topology).validate(references: rows)
        let actual = Set(rows.map(ShardReferencePosition.init))
        let required = payload.requiredReferencePositions.filter { unit.operators.contains($0.operatorId) }
        let missing = required.filter { !actual.contains($0) }.count
        guard !required.isEmpty, missing == 0 else {
            throw failure("Shard \(unit.rawValue) omits \(missing) of \(required.count) previously mapped canonical positions (coverage must be nonempty).")
        }
    }

    private func baselineDirectory(_ identity: String) -> URL {
        root.appendingPathComponent("baselines").appendingPathComponent(identity)
    }

    private func shardDirectory(_ unit: OperatorDatasetUnit, version: String) -> URL {
        root.appendingPathComponent("operators").appendingPathComponent(unit.rawValue).appendingPathComponent(version)
    }

    private func failure(_ message: String) -> DatasetPreservationError { .conflict(message) }

    private static func ordered(_ rows: [OperatorStopReference]) -> [OperatorStopReference] {
        rows.sorted { ($0.operatorId, $0.journeyId, $0.sequence) < ($1.operatorId, $1.journeyId, $1.sequence) }
    }

    private static func counts(_ rows: [OperatorStopReference]) -> [String: Int] {
        Dictionary(grouping: rows, by: \.operatorId).mapValues(\.count)
    }

    private static func validSources(_ sources: [DatasetSourceProvenance]) -> Bool {
        let seconds = ISO8601DateFormatter()
        let fractionalSeconds = ISO8601DateFormatter()
        fractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return !sources.isEmpty && sources.allSatisfy { source in
            !source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && [source.sourceTimestamp, source.retrievedAt].compactMap { $0 }
                    .allSatisfy { seconds.date(from: $0) != nil || fractionalSeconds.date(from: $0) != nil }
        }
    }

    private static func isSafeComponent(_ text: String) -> Bool {
        !text.isEmpty && text != "." && text != ".."
            && text.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 }
    }

    private static func read<T: Decodable>(_ file: String, in path: URL) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: path.appendingPathComponent(file)))
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func stageDirectory(_ directory: URL, files: [String: Data]) throws {
        let manager = FileManager.default
        let parent = directory.deletingLastPathComponent()
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let temporary = parent.appendingPathComponent(".stage-\(UUID())")
        try manager.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: temporary) }
        for (file, data) in files { try data.write(to: temporary.appendingPathComponent(file)) }
        try manager.moveItem(at: temporary, to: directory)
    }

    static func digest(_ bytes: Data) throws -> String {
        // Use platform SHA-256 tools so SwiftPM stays dependency-free on Ubuntu and macOS.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("payload")
        try bytes.write(to: file)
        let process = Process()
        #if os(Linux)
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sha256sum")
        process.arguments = [file.path]
        #else
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
        process.arguments = ["-a", "256", file.path]
        #endif
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let result = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let hash = String(data: result, encoding: .utf8)?.split(separator: " ").first,
              hash.count == 64, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw DatasetPreservationError.conflict("Could not calculate payload SHA-256.")
        }
        return String(hash)
    }
}


func runOfflineShardCommand(_ arguments: [String]) throws -> Bool {
    guard let command = arguments.first, command.hasPrefix("--offline-shard-") else { return false }
    func directory(_ index: Int) -> URL { URL(fileURLWithPath: arguments[index], isDirectory: true) }
    switch command {
    case "--offline-shard-baseline" where arguments.count == 3 || arguments.count == 4:
        let production = try ProductionDatasetSnapshot.load(from: directory(1))
        let sources = arguments.count == 4
            ? try JSONDecoder().decode([DatasetSourceProvenance].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[3])))
            : nil
        let manifest = try OperatorShardStaging(root: directory(2)).stageBaseline(production, sources: sources)
        print("TD baseline \(manifest.dependency.identity)")
    case "--offline-shard-verify-fares" where arguments.count == 5:
        let (_, previous) = try OperatorShardStaging(root: directory(1)).loadBaseline(arguments[2])
        let (_, candidate) = try OperatorShardStaging(root: directory(3)).loadBaseline(arguments[4])
        try Topology(previous.topology).validateFareCompatibility(with: Topology(candidate.topology),
                                                                 verifiedBaseline: arguments[2])
    case "--offline-shard-register" where arguments.count == 6:
        guard let unit = OperatorDatasetUnit(rawValue: arguments[3]) else {
            throw DatasetPreservationError.conflict("Unknown operator shard unit.")
        }
        let decoder = JSONDecoder()
        let rows = try decoder.decode([OperatorStopReference].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[4])))
        let sources = try decoder.decode([DatasetSourceProvenance].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[5])))
        let manifest = try OperatorShardStaging(root: directory(1)).register(
            unit: unit, references: rows, baselineID: arguments[2], sources: sources
        )
        print("Validated shard \(unit.rawValue) \(manifest.version) (\(rows.count) references).")
    case "--offline-shard-verify" where arguments.count == 3:
        let registry = try OperatorShardStaging(root: directory(1)).validateRegistry(baselineID: arguments[2])
        let missing = OperatorDatasetUnit.allCases.map(\.rawValue).filter { registry.latest[$0] == nil }
        print("Registry validation passed: \(registry.latest.count) / \(OperatorDatasetUnit.allCases.count) compatible units.")
        if !missing.isEmpty { print("Missing units: \(missing.joined(separator: ", "))") }
        print("Legacy composition and publication are outside this staging command.")
    default:
        throw DatasetPreservationError.conflict("""
            Usage:
              --offline-shard-baseline VERIFIED_PRODUCTION STAGING_ROOT [PROVENANCE_JSON]
              --offline-shard-register STAGING_ROOT BASELINE_ID UNIT REFERENCES_JSON PROVENANCE_JSON
              --offline-shard-verify STAGING_ROOT BASELINE_ID
              --offline-shard-verify-fares ACTIVE_ROOT ACTIVE_ID CANDIDATE_ROOT CANDIDATE_ID
            """)
    }
    return true
}
