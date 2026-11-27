import Foundation

enum LegacyPublicationEligibility: Equatable {
    case unchanged
    case pending(earliestVersion: String)
    case eligible(proposedVersion: String)

    static func evaluate(changed: Bool, lastPublishedVersion: String, at date: Date) throws -> Self {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.isLenient = false
        guard let publishedDay = formatter.date(from: lastPublishedVersion),
              formatter.string(from: publishedDay) == lastPublishedVersion else {
            throw DatasetPreservationError.conflict("Invalid legacy publication version.")
        }
        guard changed else { return .unchanged }
        let today = formatter.string(from: date)
        if today > lastPublishedVersion { return .eligible(proposedVersion: today) }
        var calendar = formatter.calendar!
        calendar.timeZone = formatter.timeZone
        guard let next = calendar.date(byAdding: .day, value: 1, to: publishedDay) else {
            throw DatasetPreservationError.conflict("Cannot calculate the next legacy publication day.")
        }
        return .pending(earliestVersion: formatter.string(from: next))
    }
}

struct LegacyDatasetComposer {
    let staging: OperatorShardStaging
    let verifiedProduction: ProductionDatasetSnapshot

    struct Result {
        let snapshot: ProductionDatasetSnapshot
        let referencesChanged: Bool

        func stage(to destination: URL) throws {
            try snapshot.stage(to: destination) { temporary in
                let decoded = try ProductionDatasetSnapshot.load(from: temporary)
                _ = try ProductionDatasetPreservation(baseline: decoded)
                guard decoded.data.operatorStopReferences == snapshot.data.operatorStopReferences,
                      decoded.metadata.version == snapshot.metadata.version,
                      decoded.metadata.generatedAt == snapshot.metadata.generatedAt,
                      decoded.metadata.fareDataUpdatedAt == snapshot.metadata.fareDataUpdatedAt else {
                    throw DatasetPreservationError.conflict("Legacy staged output did not round-trip.")
                }
            }
        }
    }

    func compose(baselineID: String, lastPublished: ProductionDatasetSnapshot? = nil) throws -> Result {
        let (payload, references) = try staging.legacyInputs(baselineID: baselineID, verifiedProduction: verifiedProduction)
        let core = payload.topology
        let previous = lastPublished ?? verifiedProduction
        if lastPublished != nil {
            let prior = previous.data
            let priorCore = MasterData(
                operators: prior.operators, routes: prior.routes, journeys: prior.journeys,
                journeyStops: prior.journeyStops, stops: prior.stops, schedules: prior.schedules,
                operatorStopReferences: []
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard try encoder.encode(priorCore) == encoder.encode(core),
                  try encoder.encode(previous.shapes) == encoder.encode(payload.journeyShapes),
                  previous.metadata.fareDataUpdatedAt == payload.metadata.fareDataUpdatedAt else {
                throw DatasetPreservationError.conflict("Last published snapshot has a different TD topology, shapes or fare metadata.")
            }
        }
        let operators = Set(OperatorDatasetUnit.allCases.flatMap(\.operators))
        guard Set(verifiedProduction.data.operatorStopReferences.map(\.operatorId)) == operators else {
            throw DatasetPreservationError.conflict("Legacy snapshot contains references outside the supported shard units.")
        }
        let candidate = MasterData(
            operators: core.operators, routes: core.routes, journeys: core.journeys, journeyStops: core.journeyStops,
            stops: core.stops, schedules: [], operatorStopReferences: references
        )
        let composed = try ProductionDatasetPreservation(baseline: previous)
            .compose(candidate: candidate, refreshedOperators: operators)
        // Reuse legacy row order for every existing position. P2 sorts newly
        // added positions, so appending those is also deterministic.
        var byPosition = Dictionary(uniqueKeysWithValues: composed.data.operatorStopReferences.map {
            (ShardReferencePosition($0), $0)
        })
        var ordered = previous.data.operatorStopReferences.compactMap {
            byPosition.removeValue(forKey: ShardReferencePosition($0))
        }
        ordered += composed.data.operatorStopReferences.filter { byPosition[ShardReferencePosition($0)] != nil }
        return Result(snapshot: .init(
            data: .init(operators: core.operators, routes: core.routes, journeys: core.journeys,
                        journeyStops: core.journeyStops, stops: core.stops, schedules: composed.data.schedules,
                        operatorStopReferences: ordered),
            shapes: payload.journeyShapes, metadata: composed.metadata
        ), referencesChanged: ordered != previous.data.operatorStopReferences)
    }
}

func runOfflineLegacyCommand(_ arguments: [String]) throws -> Bool {
    guard arguments.first == "--offline-compose-legacy" else { return false }
    guard arguments.count == 7, let at = ISO8601DateFormatter().date(from: arguments[5]) else {
        throw DatasetPreservationError.conflict("""
            Usage: --offline-compose-legacy VERIFIED_PRODUCTION SHARD_ROOT BASELINE_ID OUTPUT AS_OF_ISO LAST_PUBLISHED_LEGACY_DIRECTORY
            """)
    }
    let start = ProcessInfo.processInfo.systemUptime
    let production = try ProductionDatasetSnapshot.load(from: URL(fileURLWithPath: arguments[1], isDirectory: true))
    let staging = OperatorShardStaging(root: URL(fileURLWithPath: arguments[2], isDirectory: true))
    let previous = URL(fileURLWithPath: arguments[6], isDirectory: true)
    let published = previous.standardizedFileURL == URL(fileURLWithPath: arguments[1], isDirectory: true).standardizedFileURL
        ? nil : try ProductionDatasetSnapshot.load(from: previous)
    let publishedVersion = (published ?? production).metadata.version
    guard publishedVersion >= production.metadata.version else {
        throw DatasetPreservationError.conflict("Last published day precedes the verified legacy baseline.")
    }
    let result = try LegacyDatasetComposer(staging: staging, verifiedProduction: production)
        .compose(baselineID: arguments[3], lastPublished: published)
    let eligibility = try LegacyPublicationEligibility.evaluate(changed: result.referencesChanged,
                                                               lastPublishedVersion: publishedVersion, at: at)
    try result.stage(to: URL(fileURLWithPath: arguments[4], isDirectory: true))
    print("Legacy snapshot validated and staged in \(ProcessInfo.processInfo.systemUptime - start)s.")
    switch eligibility {
    case .unchanged: print("Daily version policy: unchanged; no new revision.")
    case .pending(let version): print("Daily version policy: pending until \(version) Hong Kong time.")
    case .eligible(let version): print("Daily version policy: next candidate version \(version); publication approval still required.")
    }
    return true
}
