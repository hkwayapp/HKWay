import Foundation

struct ProductionDatasetSnapshot {
    let data: MasterData
    let shapes: [JourneyShape]
    let metadata: DataVersion

    static func load(from directory: URL) throws -> Self {
        let data = try readMasterData(from: directory)
        return try .init(
            data: data, shapes: read("journey_shapes", from: directory),
            metadata: read("dataset_info", from: directory)
        )
    }

    static func readMasterData(from directory: URL) throws -> MasterData {
        try MasterData(
            operators: read("operators", from: directory),
            routes: read("routes", from: directory),
            journeys: read("journeys", from: directory),
            journeyStops: read("journey_stops", from: directory),
            stops: read("stops", from: directory),
            schedules: read("schedules", from: directory),
            operatorStopReferences: read("operator_stop_references", from: directory)
        )
    }

    private static func read<T: Decodable>(_ file: String, from directory: URL) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: directory.appendingPathComponent(file + ".json")))
    }

    /// Exposes all nine files together and leaves existing snapshots untouched on failure.
    func stage(to destination: URL, validate: ((URL) throws -> Void)? = nil) throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw DatasetPreservationError.conflict("Staging destination already exists: \(destination.path)")
        }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".dataset-\(UUID())")
        defer { try? manager.removeItem(at: temporary) }
        try MasterDataExporter().export(data, to: temporary, metadata: metadata, shapes: shapes)
        try validate?(temporary)
        try manager.moveItem(at: temporary, to: destination)
    }
}

enum DatasetPreservationError: LocalizedError {
    case conflict(String)

    var errorDescription: String? {
        guard case .conflict(let message) = self else { return nil }
        return "Production compatibility blocked: \(message)"
    }
}

struct ProductionDatasetPreservation {
    private static let requiredRetainedOperators: Set<String> = ["GMB", "LRTFeeder"]

    private let baseline: ProductionDatasetSnapshot
    private let original: Topology
    private let oldReferences: [String: [OperatorStopReference]]

    init(baseline: ProductionDatasetSnapshot) throws {
        let topology = try Topology(baseline.data)
        try topology.validate(shapes: baseline.shapes)
        try topology.validate(references: baseline.data.operatorStopReferences)
        let groups = Dictionary(grouping: baseline.data.operatorStopReferences, by: \.operatorId)
        guard let fareDate = baseline.metadata.fareDataUpdatedAt,
              ISO8601DateFormatter().date(from: fareDate) != nil,
              ISO8601DateFormatter().date(from: baseline.metadata.generatedAt) != nil,
              Self.requiredRetainedOperators.isSubset(of: Set(groups.keys)) else {
            throw DatasetPreservationError.conflict("Baseline must have verified fare freshness and GMB/LRTFeeder coverage.")
        }
        self.baseline = baseline
        original = topology
        oldReferences = groups
    }

    /// Only explicitly successful operators may be replaced. Failed or unavailable
    /// sources retain their complete validated baseline group and its dependencies.
    func compose(candidate: MasterData, refreshedOperators: Set<String>) throws -> ProductionDatasetSnapshot {
        let current = try Topology(candidate)
        let incoming = Dictionary(grouping: candidate.operatorStopReferences, by: \.operatorId)
        guard Set(incoming.keys).isSubset(of: refreshedOperators) else {
            throw DatasetPreservationError.conflict("Candidate contains unapproved or failed operator results.")
        }

        try original.validateFareCompatibility(with: current, verifiedBaseline: baseline.metadata.version)

        var combined: [OperatorStopReference] = []
        for operatorID in Set(oldReferences.keys).union(refreshedOperators).sorted() {
            let previous = oldReferences[operatorID] ?? []
            if refreshedOperators.contains(operatorID) {
                guard let next = incoming[operatorID], !next.isEmpty else {
                    throw DatasetPreservationError.conflict("Missing replacement references for \(operatorID).")
                }
                let positions = Set(next.map(ReferencePosition.init))
                let missing = previous.filter {
                    original.sameJourney($0.journeyId, as: current) && !positions.contains(ReferencePosition($0))
                }
                guard missing.isEmpty else {
                    throw DatasetPreservationError.conflict("\(operatorID) replacement omits \(missing.count) previously mapped positions on unchanged TD journeys.")
                }
                combined += next
            } else {
                let dependencies = Set(previous.map(\.journeyId)).sorted()
                let incompatible = dependencies.filter { !original.sameJourney($0, as: current) }
                guard incompatible.isEmpty else {
                    throw DatasetPreservationError.conflict("Cannot retain \(operatorID): \(incompatible.count) incompatible TD journeys (examples: \(incompatible.prefix(5).joined(separator: ", "))).")
                }
                combined += previous
            }
        }
        try current.validate(references: combined)

        let retainedDependencies = Set(baseline.shapes.map(\.journeyId) + baseline.data.schedules.map(\.journeyId))
        let incompatible = retainedDependencies.sorted().filter { !original.sameJourney($0, as: current) }
        guard incompatible.isEmpty else {
            throw DatasetPreservationError.conflict("Cannot retain journey shapes or schedules: \(incompatible.count) incompatible TD journeys (examples: \(incompatible.prefix(5).joined(separator: ", "))).")
        }
        try current.validate(shapes: baseline.shapes)
        guard candidate.schedules.isEmpty else {
            throw DatasetPreservationError.conflict("Schedule replacement requires a separate validated source.")
        }

        let ordered = combined.sorted {
            ($0.operatorId, $0.journeyId, $0.sequence) < ($1.operatorId, $1.journeyId, $1.sequence)
        }
        let merged = MasterData(
            operators: candidate.operators, routes: candidate.routes, journeys: candidate.journeys,
            journeyStops: candidate.journeyStops, stops: candidate.stops, schedules: baseline.data.schedules,
            operatorStopReferences: ordered
        )
        // This command stages compatibility evidence only. Preserve production
        // freshness verbatim until a separate release step approves a new version.
        return .init(data: merged, shapes: baseline.shapes, metadata: baseline.metadata)
    }
}

private struct ReferencePosition: Hashable {
    let operatorID: String
    let journeyID: String
    let sequence: Int

    init(_ row: OperatorStopReference) {
        operatorID = row.operatorId
        journeyID = row.journeyId
        sequence = row.sequence
    }
}

struct Topology {
    let operators: Set<String>
    let routes: [String: Route]
    let journeys: [String: Journey]
    let stops: Set<String>
    let stopSequences: [String: [Int: StopPosition]]

    struct StopPosition: Equatable {
        let stopID: String
        let pickDrop: String?
    }

    init(_ data: MasterData) throws {
        try MasterDataValidator().validate(data)
        let operators = Set(data.operators.map(\.id))
        let routes = Dictionary(data.routes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let journeys = Dictionary(data.journeys.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let stops = Set(data.stops.map(\.id))
        guard !operators.isEmpty, !routes.isEmpty, !journeys.isEmpty, !stops.isEmpty,
              operators.count == data.operators.count, routes.count == data.routes.count,
              journeys.count == data.journeys.count, stops.count == data.stops.count,
              Set(data.schedules.map(\.id)).count == data.schedules.count,
              data.routes.allSatisfy({ !$0.componentOperatorIds.isEmpty && $0.componentOperatorIds.isSubset(of: operators) }) else {
            throw DatasetPreservationError.conflict("Empty or duplicate canonical IDs, or invalid route membership.")
        }
        var stopSequences: [String: [Int: StopPosition]] = [:]
        for row in data.journeyStops {
            let position = StopPosition(stopID: row.stopId, pickDrop: row.stopPickDrop)
            guard row.sequence > 0, stopSequences[row.journeyId, default: [:]].updateValue(position, forKey: row.sequence) == nil else {
                throw DatasetPreservationError.conflict("Duplicate or invalid TD stop sequence for \(row.journeyId)/\(row.sequence).")
            }
        }
        for journey in data.journeys {
            let positions = stopSequences[journey.id] ?? [:]
            let tiers = journey.sectionFareTiers ?? []
            guard !positions.isEmpty, stops.contains(journey.originStopId), stops.contains(journey.destinationStopId),
                  positions.keys.min().flatMap({ positions[$0]?.stopID }) == journey.originStopId,
                  positions.keys.max().flatMap({ positions[$0]?.stopID }) == journey.destinationStopId,
                  journey.adultFullFareCents.map({ $0 >= 0 }) ?? true,
                  Set(tiers.map(\.boardingStopSequence)).count == tiers.count,
                  tiers.allSatisfy({ $0.fareCents >= 0 && positions[$0.boardingStopSequence] != nil }) else {
                throw DatasetPreservationError.conflict("Invalid journey topology or fare references for \(journey.id).")
            }
        }
        self.operators = operators
        self.routes = routes
        self.journeys = journeys
        self.stops = stops
        self.stopSequences = stopSequences
    }

    func sameJourney(_ id: String, as other: Topology) -> Bool {
        guard let previous = journeys[id], let current = other.journeys[id],
              let oldRoute = routes[previous.routeId], let newRoute = other.routes[current.routeId] else { return false }
        return previous.routeId == current.routeId && previous.direction == current.direction
            && previous.serviceType == current.serviceType && oldRoute.number == newRoute.number
            && oldRoute.componentOperatorIds == newRoute.componentOperatorIds
            && stopSequences[id] == other.stopSequences[id]
    }

    /// Sequence-only input can corroborate an already published tier on the same TD
    /// topology. It cannot establish a new boarding identity or carry across a topology revision.
    func validateFareCompatibility(with candidate: Topology, verifiedBaseline: String) throws {
        var discrepancies: [String] = []
        for id in Set(journeys.keys).union(candidate.journeys.keys).sorted() {
            let before = journeys[id]
            let after = candidate.journeys[id]
            let route = before.flatMap { routes[$0.routeId] } ?? after.flatMap { candidate.routes[$0.routeId] }
            let subject = "\(route?.componentOperatorIds.sorted().joined(separator: "+") ?? "?") \(route?.number ?? "?") journey \(id)"
            if let before, let after, before.adultFullFareCents != after.adultFullFareCents {
                let previous = before.adultFullFareCents.map(String.init) ?? "none"
                let current = after.adultFullFareCents.map(String.init) ?? "none"
                discrepancies.append("\(subject): unverified full fare \(previous) -> \(current) cents")
            }
            let oldTiers = before?.sectionFareTiers ?? []
            let newTiers = after?.sectionFareTiers ?? []
            guard !oldTiers.isEmpty || !newTiers.isEmpty else {
                if let before, let after, before.sectionFareTiers != after.sectionFareTiers {
                    discrepancies.append("\(subject): unverified section fare representation change")
                }
                continue
            }
            let sameTopology = sameJourney(id, as: candidate)
            guard before?.sectionFareTiers != after?.sectionFareTiers || !sameTopology else { continue }

            let oldBySequence = Dictionary(uniqueKeysWithValues: oldTiers.map { ($0.boardingStopSequence, $0.fareCents) })
            let newBySequence = Dictionary(uniqueKeysWithValues: newTiers.map { ($0.boardingStopSequence, $0.fareCents) })
            if sameTopology && oldBySequence == newBySequence {
                discrepancies.append("\(subject): unverified section fare order change")
            }
            for sequence in Set(oldBySequence.keys).union(newBySequence.keys).sorted() {
                let reason: String
                switch (oldBySequence[sequence], newBySequence[sequence]) {
                case (nil, _): reason = "no verified published tier"
                case (_, nil): reason = "verified tier missing from candidate"
                case (let old, let new) where old != new: reason = "unverified fare amount change"
                default:
                    guard !sameTopology else { continue }
                    reason = "journey identity or ordered TD topology changed"
                }
                let oldFare = oldBySequence[sequence].map(String.init) ?? "none"
                let newFare = newBySequence[sequence].map(String.init) ?? "none"
                let oldStop = boardingPosition(journey: id, sequence: sequence)
                let newStop = candidate.boardingPosition(journey: id, sequence: sequence)
                discrepancies.append("\(subject) sequence \(sequence): \(reason); \(oldFare) -> \(newFare) cents; TD stop \(oldStop) -> \(newStop)")
            }
        }
        guard discrepancies.isEmpty else {
            throw DatasetPreservationError.conflict(
                "Unresolved fare discrepancies against verified TD baseline \(verifiedBaseline):\n"
                    + discrepancies.joined(separator: "\n")
            )
        }
    }

    private func boardingPosition(journey: String, sequence: Int) -> String {
        guard let positions = stopSequences[journey], let stop = positions[sequence] else { return "none" }
        let occurrence = positions.filter { $0.key <= sequence && $0.value.stopID == stop.stopID }.count
        return "\(stop.stopID) occurrence \(occurrence)"
    }

    func validate(references: [OperatorStopReference]) throws {
        var seen = Set<ReferencePosition>()
        for row in references {
            guard let journey = journeys[row.journeyId],
                  routes[journey.routeId]?.supportsOperator(row.operatorId) == true,
                  operators.contains(row.operatorId), stops.contains(row.stopId),
                  stopSequences[row.journeyId]?[row.sequence]?.stopID == row.stopId,
                  !row.operatorStopId.isEmpty, !row.operatorDirection.isEmpty,
                  seen.insert(ReferencePosition(row)).inserted else {
                throw DatasetPreservationError.conflict("Invalid or duplicate operator reference \(row.operatorId)/\(row.journeyId)/\(row.sequence).")
            }
        }
    }

    func validate(shapes: [JourneyShape]) throws {
        var seen = Set<String>()
        for shape in shapes {
            guard journeys[shape.journeyId] != nil, seen.insert(shape.journeyId).inserted,
                  shape.coordinates.count >= 2,
                  shape.coordinates.allSatisfy({ (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude) }) else {
                throw DatasetPreservationError.conflict("Invalid or orphaned journey shape \(shape.journeyId).")
            }
        }
    }
}
