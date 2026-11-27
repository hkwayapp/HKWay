import Foundation

struct OfflineOperatorGeneration {
    func stage(unit: OperatorDatasetUnit, baselineID: String, registry: URL, raw: URL, output: URL) async throws {
        let staging = OperatorShardStaging(root: registry)
        let (_, baseline) = try staging.loadBaseline(baselineID)
        let archive = try OfflineResponseArchive(directory: raw)
        let sourceBytes = try Data(contentsOf: raw.appendingPathComponent("sources.json"))
        let sources = try JSONDecoder().decode([DatasetSourceProvenance].self, from: sourceBytes)
        guard !sources.isEmpty else { throw DatasetPreservationError.conflict("Missing source provenance.") }
        let data = baseline.topology
        let refs = try await DatasetHTTP.$replay.withValue(archive) {
            switch unit {
            case .kmbLwb:
                try await KMBOperatorStopReferenceBuilder().buildAll(
                    routes: data.routes, journeys: data.journeys, journeyStops: data.journeyStops, stops: data.stops
                ).references
            case .ctb:
                try await CTBOperatorStopReferenceBuilder().buildAll(
                    routes: data.routes, journeys: data.journeys, journeyStops: data.journeyStops, stops: data.stops
                ).references
            case .nlb:
                try await NLBOperatorStopReferenceBuilder().buildAll(
                    routes: data.routes, journeys: data.journeys, journeyStops: data.journeyStops, stops: data.stops
                ).references
            case .feeder:
                try await MTRBusOperatorStopReferenceBuilder().buildAll(
                    routes: data.routes, journeys: data.journeys, journeyStops: data.journeyStops, stops: data.stops
                ).flatMap(\.references)
            case .gmb:
                try await gmbReferences(in: data)
            }
        }
        try await DatasetHTTP.requireCompleteSources()
        print("Offline \(unit.rawValue) generated \(refs.count) references before coverage validation.")
        try staging.validateGeneratedReferences(refs, unit: unit, baseline: baseline)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw DatasetPreservationError.conflict("Offline reference staging destination already exists.")
        }
        let privateOutput = output.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: privateOutput, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: privateOutput) }
        try encoder.encode(refs).write(to: privateOutput.appendingPathComponent("references.json"))
        try sourceBytes.write(to: privateOutput.appendingPathComponent("sources.json"))
        try FileManager.default.moveItem(at: privateOutput, to: output)
    }

    private func gmbReferences(in baseline: MasterData) async throws -> [OperatorStopReference] {
        let generated = try await GMBUpdateCommand().generate()
        let routeIDs = Set(baseline.routes.filter { $0.supportsOperator("GMB") }.map(\.id))
        let journeys = baseline.journeys.filter { routeIDs.contains($0.routeId) }
        let journeyIDs = Set(journeys.map(\.id))
        // The GMB updater also produces topology. A shard may only replace references
        // when that raw feed agrees with the pinned canonical GMB topology and fares.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard try encoder.encode(generated.routes.sorted { $0.id < $1.id }) ==
                    encoder.encode(baseline.routes.filter { routeIDs.contains($0.id) }.sorted { $0.id < $1.id }),
              try encoder.encode(generated.journeys.sorted { $0.id < $1.id }) ==
                    encoder.encode(journeys.sorted { $0.id < $1.id }),
              try encoder.encode(generated.journeyStops.sorted { ($0.journeyId, $0.sequence) < ($1.journeyId, $1.sequence) }) ==
                    encoder.encode(baseline.journeyStops.filter { journeyIDs.contains($0.journeyId) }
                        .sorted { ($0.journeyId, $0.sequence) < ($1.journeyId, $1.sequence) })
        else { throw DatasetPreservationError.conflict("GMB topology or fares differ from the pinned baseline.") }
        return generated.references
    }
}

struct OfflineTDGeneration {
    func stage(verified: ProductionDatasetSnapshot, raw: URL, output: URL) async throws {
        let boundaries: [DistrictBoundary]?
        if FileManager.default.fileExists(atPath: raw.appendingPathComponent("responses.json").path) {
            let archive = try OfflineResponseArchive(directory: raw)
            boundaries = try await DatasetHTTP.$replay.withValue(archive) {
                try await DistrictBoundaryClient().fetch()
            }
            guard boundaries?.isEmpty == false else {
                throw DatasetPreservationError.conflict("Captured district boundaries are empty.")
            }
        } else {
            boundaries = nil
        }
        let candidate = try OfflineTDResources.$directory.withValue(raw) {
            try build(verified: verified.data, boundaries: boundaries)
        }
        let result = try ProductionDatasetPreservation(baseline: verified).compose(candidate: candidate, refreshedOperators: [])
        try result.stage(to: output)
    }

    private func build(verified: MasterData, boundaries: [DistrictBoundary]?) throws -> MasterData {
        let operators = try RealOperatorBuilder().build()
        let routes = try RealRouteBuilder().build()
        let journeys = try RealJourneyBuilder().build()
        let journeyStops = try RealJourneyStopBuilder().build()
        let stops = try RealStopBuilder().build()
        print("Offline TD parsed \(routes.count) routes, \(journeys.count) journeys and \(journeyStops.count) ordered positions.")
        let gmbRoutes = verified.routes.filter { $0.componentOperatorIds == ["GMB"] }
        let gmbRouteIDs = Set(gmbRoutes.map(\.id))
        let gmbJourneys = verified.journeys.filter { gmbRouteIDs.contains($0.routeId) }
        let gmbJourneyIDs = Set(gmbJourneys.map(\.id))
        let gmbPositions = verified.journeyStops.filter { gmbJourneyIDs.contains($0.journeyId) }
        let gmbStopIDs = Set(gmbPositions.map(\.stopId))
        let rawOperatorIDs = Set(operators.map(\.id))
        let assembledStops = assembleStops(raw: stops, verified: verified.stops,
                                           carriedStopIDs: gmbStopIDs, boundaries: boundaries)
        return MasterData(operators: operators + verified.operators.filter { !rawOperatorIDs.contains($0.id) },
                          routes: routes + gmbRoutes, journeys: journeys + gmbJourneys,
                          journeyStops: journeyStops + gmbPositions,
                          stops: assembledStops, schedules: [], operatorStopReferences: [])
    }

    func assembleStops(raw: [Stop], verified: [Stop], carriedStopIDs: Set<String>,
                       boundaries: [DistrictBoundary]?) -> [Stop] {
        let rawStopIDs = Set(raw.map(\.id))
        let carried = verified.filter { carriedStopIDs.contains($0.id) && !rawStopIDs.contains($0.id) }
        if let boundaries {
            return StopGeographyEnricher(boundaries: boundaries).enrich(raw + carried)
        }

        let oldStops = Dictionary(uniqueKeysWithValues: verified.map { ($0.id, $0) })
        let retainedGeography = raw.map { stop -> Stop in
            guard let old = oldStops[stop.id], old.latitude == stop.latitude, old.longitude == stop.longitude else { return stop }
            return Stop(id: stop.id, nameEnglish: stop.nameEnglish, nameTraditional: stop.nameTraditional,
                        nameSimplified: stop.nameSimplified, latitude: stop.latitude, longitude: stop.longitude,
                        regionId: old.regionId, districtId: old.districtId)
        }
        return retainedGeography + carried
    }
}

func runOfflineGeneratorCommand(_ args: [String]) async throws -> Bool {
    guard let command = args.first, command.hasPrefix("--offline-generate-")
            || ["--offline-bootstrap-ctb-cache", "--offline-plan-ctb-cache"].contains(command) else { return false }
    func path(_ index: Int) -> URL { URL(fileURLWithPath: args[index], isDirectory: true) }
    if command == "--offline-bootstrap-ctb-cache", args.count == 3 || args.count == 4 {
        let now = args.count == 3 ? Date() : try cacheClock(args[3])
        let result = try CTBStopDetailCache(directory: path(2)).bootstrap(from: path(1), now: now)
        print("CTB cache bootstrap: \(result.valid) verified, \(result.invalid) invalid, \(result.expired) expired.")
    } else if command == "--offline-plan-ctb-cache", args.count == 6 {
        let plan = try CTBStopDetailCache(directory: path(2)).refreshPlan(
            for: path(1), incoming: CTBStopDetailCache(directory: path(3)), now: cacheClock(args[4])
        )
        try plan.write(to: URL(fileURLWithPath: args[5]), options: .atomic)
    } else if command == "--offline-generate-td", args.count == 4 {
        try await OfflineTDGeneration().stage(verified: ProductionDatasetSnapshot.load(from: path(1)), raw: path(2), output: path(3))
    } else if command == "--offline-generate-operator", args.count == 6, let unit = OperatorDatasetUnit(rawValue: args[3]) {
        try await OfflineOperatorGeneration().stage(unit: unit, baselineID: args[2], registry: path(1), raw: path(4), output: path(5))
    } else {
        throw DatasetPreservationError.conflict("""
            Usage:
              --offline-bootstrap-ctb-cache VERIFIED_ARCHIVE CACHE_DIRECTORY [AS_OF]
              --offline-plan-ctb-cache VERIFIED_ARCHIVE RESTORED INCOMING AS_OF OUTPUT
              --offline-generate-td VERIFIED_PRODUCTION RAW_TD OUTPUT
              --offline-generate-operator REGISTRY BASELINE_ID UNIT RAW_RESPONSES OUTPUT
            """)
    }
    return true
}

private func cacheClock(_ timestamp: String) throws -> Date {
    guard let date = CTBStopDetailCache.archiveDate(timestamp) else {
        throw DatasetPreservationError.conflict("Invalid CTB cache clock.")
    }
    return date
}
