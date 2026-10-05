import Foundation
import Observation

struct TVBusRoute: Codable, Identifiable, Hashable {
    let id: String
    let number: String
    let operatorIds: [String]
}

struct TVBusJourney: Codable, Identifiable, Hashable {
    let destinationStopId: String
    let direction: String
    let id: String
    let originStopId: String
    let routeId: String
    let serviceType: String
}

struct TVBusStop: Codable, Identifiable, Hashable {
    let id: String
    let nameEnglish: String
    let nameSimplified: String
    let nameTraditional: String

    func name(_ language: TVLanguage) -> String {
        switch language {
        case .english: nameEnglish
        case .traditionalChinese: nameTraditional
        case .simplifiedChinese: nameSimplified
        }
    }
}

struct TVBusJourneyStop: Codable, Hashable {
    let journeyId: String
    let sequence: Int
    let stopId: String
    let stopPickDrop: String?
}

struct TVOperatorStopReference: Codable, Hashable, Sendable {
    let operatorId: String
    let journeyId: String
    let stopId: String
    let sequence: Int
    let operatorStopId: String
    let publicStopCode: String?
    let operatorLatitude: Double?
    let operatorLongitude: Double?
    let operatorServiceType: String
    let operatorDirection: String
}

struct TVBusStopCall: Identifiable, Hashable {
    let journeyStop: TVBusJourneyStop
    let stop: TVBusStop

    var id: String {
        "\(journeyStop.journeyId)|\(journeyStop.sequence)|\(journeyStop.stopId)"
    }
}

struct TVBusDirection: Identifiable, Hashable {
    let journey: TVBusJourney
    let origin: TVBusStop
    let destination: TVBusStop
    var id: String { journey.id }
}

struct TVFavoriteBusRoute: Codable, Identifiable, Hashable {
    let journeyID: String
    let routeID: String
    let number: String
    let operatorIDs: [String]
    let originEnglish: String
    let originTraditional: String
    let originSimplified: String
    let destinationEnglish: String
    let destinationTraditional: String
    let destinationSimplified: String
    let selectedStopID: String?
    let selectedStopEnglish: String?
    let selectedStopTraditional: String?
    let selectedStopSimplified: String?
    let selectedStopSequence: Int?

    var id: String {
        [routeID, journeyID, selectedStopID ?? "direction"].joined(separator: "|")
    }

    func origin(_ language: TVLanguage) -> String {
        switch language {
        case .english: originEnglish
        case .traditionalChinese: originTraditional
        case .simplifiedChinese: originSimplified
        }
    }

    func destination(_ language: TVLanguage) -> String {
        switch language {
        case .english: destinationEnglish
        case .traditionalChinese: destinationTraditional
        case .simplifiedChinese: destinationSimplified
        }
    }

    func selectedStop(_ language: TVLanguage) -> String? {
        switch language {
        case .english: selectedStopEnglish
        case .traditionalChinese: selectedStopTraditional
        case .simplifiedChinese: selectedStopSimplified
        }
    }
}

enum TVBusFavorites {
    static let storageKey = "tvFavoriteBusRoutes.v1"

    static func decode(_ value: String) -> [TVFavoriteBusRoute] {
        guard let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([TVFavoriteBusRoute].self, from: data)) ?? []
    }

    static func encode(_ favorites: [TVFavoriteBusRoute]) -> String {
        guard let data = try? JSONEncoder().encode(favorites) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

@MainActor
@Observable
final class TVBusDataStore {
    private(set) var routes: [TVBusRoute] = []
    private(set) var journeysByRoute: [String: [TVBusJourney]] = [:]
    private(set) var journeyStopsByJourney: [String: [TVBusJourneyStop]] = [:]
    private(set) var stopsByID: [String: TVBusStop] = [:]
    private(set) var operatorReferencesByStop: [String: [TVOperatorStopReference]] = [:]
    private(set) var isLoading = false
    private(set) var error: Error?

    private let baseURL = URL(
        string: "https://raw.githubusercontent.com/kenwongtc/HKWay/main/Dataset/"
    )!

    func load() async {
        guard routes.isEmpty, !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let routesData = data(for: "routes.json")
            async let journeysData = data(for: "journeys.json")
            async let stopsData = data(for: "stops.json")
            async let journeyStopsData = data(for: "journey_stops.json")
            async let operatorReferencesData = data(for: "operator_stop_references.json")
            let (routeBytes, journeyBytes, stopBytes, journeyStopBytes, operatorReferenceBytes) = try await (
                routesData,
                journeysData,
                stopsData,
                journeyStopsData,
                operatorReferencesData
            )

            let decoder = JSONDecoder()
            let decodedRoutes = try decoder.decode([TVBusRoute].self, from: routeBytes)
            let decodedJourneys = try decoder.decode([TVBusJourney].self, from: journeyBytes)
            let decodedStops = try decoder.decode([TVBusStop].self, from: stopBytes)
            let decodedJourneyStops = try decoder.decode([TVBusJourneyStop].self, from: journeyStopBytes)
            let decodedOperatorReferences = try decoder.decode(
                [TVOperatorStopReference].self,
                from: operatorReferenceBytes
            )

            routes = decodedRoutes.sorted { lhs, rhs in
                lhs.number.localizedStandardCompare(rhs.number) == .orderedAscending
            }
            journeysByRoute = Dictionary(grouping: decodedJourneys, by: \.routeId)
            journeyStopsByJourney = Dictionary(grouping: decodedJourneyStops, by: \.journeyId)
            stopsByID = Dictionary(uniqueKeysWithValues: decodedStops.map { ($0.id, $0) })
            operatorReferencesByStop = Dictionary(
                grouping: decodedOperatorReferences,
                by: { Self.referenceKey(journeyID: $0.journeyId, stopID: $0.stopId, sequence: $0.sequence) }
            )
        } catch {
            self.error = error
        }
    }

    func directions(for route: TVBusRoute) -> [TVBusDirection] {
        var seen = Set<String>()
        return (journeysByRoute[route.id] ?? []).compactMap { journey in
            guard let origin = stopsByID[journey.originStopId],
                  let destination = stopsByID[journey.destinationStopId]
            else { return nil }
            let key = "\(origin.id)|\(destination.id)|\(journey.direction)"
            guard seen.insert(key).inserted else { return nil }
            return TVBusDirection(journey: journey, origin: origin, destination: destination)
        }
        .sorted {
            $0.origin.nameEnglish.localizedStandardCompare($1.origin.nameEnglish) == .orderedAscending
        }
    }

    func stops(for direction: TVBusDirection) -> [TVBusStopCall] {
        (journeyStopsByJourney[direction.journey.id] ?? [])
            .sorted { $0.sequence < $1.sequence }
            .compactMap { journeyStop in
                guard let stop = stopsByID[journeyStop.stopId] else { return nil }
                return TVBusStopCall(journeyStop: journeyStop, stop: stop)
            }
    }

    func operatorReferences(for favorite: TVFavoriteBusRoute) -> [TVOperatorStopReference] {
        guard let stopID = favorite.selectedStopID,
              let sequence = favorite.selectedStopSequence
        else { return [] }

        return operatorReferencesByStop[
            Self.referenceKey(journeyID: favorite.journeyID, stopID: stopID, sequence: sequence)
        ] ?? []
    }

    private static func referenceKey(journeyID: String, stopID: String, sequence: Int) -> String {
        "\(journeyID)|\(sequence)|\(stopID)"
    }

    private func data(for filename: String) async throws -> Data {
        let localURL = try cacheDirectory().appendingPathComponent(filename)
        var request = URLRequest(
            url: baseURL.appendingPathComponent(filename),
            cachePolicy: .reloadRevalidatingCacheData,
            timeoutInterval: 45
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            try data.write(to: localURL, options: .atomic)
            return data
        } catch {
            if let cached = try? Data(contentsOf: localURL) { return cached }
            throw error
        }
    }

    private func cacheDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("HKWayTVBusData", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

extension TVFavoriteBusRoute {
    init(route: TVBusRoute, direction: TVBusDirection, stopCall: TVBusStopCall) {
        journeyID = direction.journey.id
        routeID = route.id
        number = route.number
        operatorIDs = route.operatorIds
        originEnglish = direction.origin.nameEnglish
        originTraditional = direction.origin.nameTraditional
        originSimplified = direction.origin.nameSimplified
        destinationEnglish = direction.destination.nameEnglish
        destinationTraditional = direction.destination.nameTraditional
        destinationSimplified = direction.destination.nameSimplified
        selectedStopID = stopCall.stop.id
        selectedStopEnglish = stopCall.stop.nameEnglish
        selectedStopTraditional = stopCall.stop.nameTraditional
        selectedStopSimplified = stopCall.stop.nameSimplified
        selectedStopSequence = stopCall.journeyStop.sequence
    }
}
