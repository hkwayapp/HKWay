import Foundation
import WidgetKit

struct TransitWidgetSnapshot: Codable, Identifiable {
    let id: String
    let routeId: String
    let routeNumber: String
    let destinationEnglish: String
    let destinationTraditional: String
    let destinationSimplified: String
    let stopEnglish: String
    let stopTraditional: String
    let stopSimplified: String
    let operatorIds: [String]
    let arrivalDates: [Date]
    let updatedAt: Date
    let etaReferences: [TransitWidgetETAReference]?
    let upcomingStops: [TransitWatchStop]?
    let boardingSequence: Int?
}

struct TransitWatchStop: Codable, Sendable {
    let sequence: Int
    let english: String
    let traditional: String
    let simplified: String
    let latitude: Double?
    let longitude: Double?
}

struct TransitWidgetETAReference: Codable, Sendable {
    let operatorId: String
    let operatorStopId: String
    let operatorServiceType: String
    let operatorDirection: String
}

enum TransitWidgetSnapshotStore {
    static let appGroupId = "group.com.kenwong.hkway"
    static let snapshotsKey = "etaWidgetSnapshots"
    static let languageKey = "etaWidgetLanguage"
    static let accessTierKey = "appAccessTier.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func save(_ snapshot: TransitWidgetSnapshot) {
        var snapshots = load()
        snapshots.removeAll { $0.id == snapshot.id }
        snapshots.append(snapshot)
        snapshots.sort {
            $0.routeNumber.localizedStandardCompare($1.routeNumber)
                == .orderedAscending
        }

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        defaults?.set(data, forKey: snapshotsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "TransitGoETAWidget")
        Task { @MainActor in
            WatchSyncManager.shared.syncSnapshots(snapshots)
        }
    }

    static func setLanguage(_ language: TransitLanguage) {
        defaults?.set(language.rawValue, forKey: languageKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "TransitGoETAWidget")
    }

    static func setAccessTier(_ tier: AppAccessTier) {
        defaults?.set(tier.rawValue, forKey: accessTierKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func removeRoute(_ routeId: String) {
        let remaining = load().filter { $0.routeId != routeId }
        guard let data = try? JSONEncoder().encode(remaining) else {
            return
        }

        defaults?.set(data, forKey: snapshotsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "TransitGoETAWidget")
        Task { @MainActor in
            WatchSyncManager.shared.syncSnapshots(remaining)
        }
    }

    static func replaceRouteSnapshots(
        _ replacements: [TransitWidgetSnapshot],
        routeId: String
    ) {
        var snapshots = load().filter { $0.routeId != routeId }
        snapshots.append(contentsOf: replacements)
        snapshots.sort {
            let routeComparison = $0.routeNumber
                .localizedStandardCompare($1.routeNumber)
            if routeComparison != .orderedSame {
                return routeComparison == .orderedAscending
            }
            return $0.destinationEnglish.localizedStandardCompare(
                $1.destinationEnglish
            ) == .orderedAscending
        }

        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        defaults?.set(data, forKey: snapshotsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "TransitGoETAWidget")
        Task { @MainActor in
            WatchSyncManager.shared.syncSnapshots(snapshots)
        }
    }

    static func load() -> [TransitWidgetSnapshot] {
        guard
            let data = defaults?.data(forKey: snapshotsKey),
            let snapshots = try? JSONDecoder().decode(
                [TransitWidgetSnapshot].self,
                from: data
            )
        else {
            return []
        }

        return snapshots
    }
}

extension TransitWidgetSnapshot {
    init(
        route: RouteEntity,
        result: RouteETAResult,
        id: String? = nil
    ) {
        self.id = id ?? "\(route.id)|\(result.journey.id)"
        routeId = route.id
        routeNumber = route.number
        destinationEnglish = result.journey.destinationStop?.displayNameEnglish
            ?? route.displayDestinationEnglish
        destinationTraditional = result.journey.destinationStop?.displayNameTraditional
            ?? route.destinationTraditional
        destinationSimplified = result.journey.destinationStop?.displayNameSimplified
            ?? route.destinationSimplified
        stopEnglish = result.stop.displayNameEnglish
        stopTraditional = result.stop.displayNameTraditional
        stopSimplified = result.stop.displayNameSimplified
        operatorIds = Array(
            Set(
                route.operators.flatMap {
                    $0.id.split(separator: "+").map(String.init)
                }
            )
        ).sorted()
        arrivalDates = result.etaRecords
            .compactMap(\.estimatedArrival)
            .filter { $0 >= Date() }
            .sorted()
            .prefix(3)
            .map { $0 }
        updatedAt = Date()
        etaReferences = [result.reference].map {
            TransitWidgetETAReference(
                operatorId: $0.operatorId,
                operatorStopId: $0.operatorStopId,
                operatorServiceType: $0.operatorServiceType,
                operatorDirection: $0.operatorDirection
            )
        }
        boardingSequence = result.journeyStop.sequence
        upcomingStops = result.journey.journeyStops
            .sorted { $0.sequence < $1.sequence }
            .compactMap { journeyStop in
                guard let stop = journeyStop.stop else { return nil }
                return TransitWatchStop(
                    sequence: journeyStop.sequence,
                    english: stop.displayNameEnglish,
                    traditional: stop.displayNameTraditional,
                    simplified: stop.displayNameSimplified,
                    latitude: stop.latitude,
                    longitude: stop.longitude
                )
            }
    }

    init(
        route: RouteEntity,
        journey: JourneyEntity,
        journeyStop: JourneyStopEntity,
        references: [OperatorStopReferenceEntity]
    ) {
        id = "\(route.id)|\(journey.id)|\(journeyStop.stop?.id ?? journeyStop.id)"
        routeId = route.id
        routeNumber = route.number
        destinationEnglish = journey.destinationStop?.displayNameEnglish
            ?? route.displayDestinationEnglish
        destinationTraditional = journey.destinationStop?.displayNameTraditional
            ?? route.destinationTraditional
        destinationSimplified = journey.destinationStop?.displayNameSimplified
            ?? route.destinationSimplified
        stopEnglish = journeyStop.stop?.displayNameEnglish ?? ""
        stopTraditional = journeyStop.stop?.displayNameTraditional ?? ""
        stopSimplified = journeyStop.stop?.displayNameSimplified ?? ""
        operatorIds = Array(Set(references.map(\.operatorId))).sorted()
        arrivalDates = []
        updatedAt = Date()
        etaReferences = references.map {
            TransitWidgetETAReference(
                operatorId: $0.operatorId,
                operatorStopId: $0.operatorStopId,
                operatorServiceType: $0.operatorServiceType,
                operatorDirection: $0.operatorDirection
            )
        }
        boardingSequence = journeyStop.sequence
        upcomingStops = journey.journeyStops
            .sorted { $0.sequence < $1.sequence }
            .compactMap { stopItem in
                guard let stop = stopItem.stop else { return nil }
                return TransitWatchStop(
                    sequence: stopItem.sequence,
                    english: stop.displayNameEnglish,
                    traditional: stop.displayNameTraditional,
                    simplified: stop.displayNameSimplified,
                    latitude: stop.latitude,
                    longitude: stop.longitude
                )
            }
    }
}
