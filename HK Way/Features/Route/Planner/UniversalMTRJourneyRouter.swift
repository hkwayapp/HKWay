import CoreLocation
import Foundation

struct UniversalMTRJourney: Identifiable {
    let feeder: UniversalJourneyLeg?
    let railJourney: MTRPlannedJourney
    let originStation: MTRStation
    let destinationStation: MTRStation
    let accessWalkDistance: CLLocationDistance
    let transferWalkDistance: CLLocationDistance
    let egressWalkDistance: CLLocationDistance
    let fareCents: Int?

    var id: String {
        let feederID = feeder?.id ?? "walk"
        return "\(feederID)|mtr-\(originStation.id)-\(destinationStation.id)"
    }

    var totalWalkDistance: CLLocationDistance {
        accessWalkDistance + transferWalkDistance + egressWalkDistance
    }

    var totalMinutes: Int {
        let walking = Int(ceil(totalWalkDistance / 75))
        let feederMinutes = feeder?.estimatedMinutes ?? 0
        let interchangeMinutes = railJourney.changes * 4
        return walking + feederMinutes + railJourney.stops * 2
            + interchangeMinutes + (feeder == nil ? 0 : 5)
    }

    var totalFareCents: Int? {
        let feederFare = feeder?.adultFareCents
        if feeder != nil, feederFare == nil { return nil }
        guard let fareCents else { return nil }
        return (feederFare ?? 0) + fareCents
    }
}

@MainActor
enum UniversalMTRJourneyRouter {
    private static let maximumWalkingDistance: CLLocationDistance = 1_000
    private static let stationConnectionRadius: CLLocationDistance = 350

    static func journeys(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        stops: [StopEntity],
        journeys: [JourneyEntity],
        servicePeriod: PlannerServicePeriod,
        preferredOriginStationID: String? = nil,
        preferredDestinationStationID: String? = nil,
        limit: Int = 6
    ) -> [UniversalMTRJourney] {
        guard let csvURL = Bundle.main.url(forResource: "MTRStations", withExtension: "csv"),
              let csv = try? String(contentsOf: csvURL, encoding: .utf8),
              let planner = try? MTRJourneyPlanner(csv: csv, lineIDs: MTRLine.all.map(\.id)) else {
            return []
        }

        // Fare metadata is supplementary. A missing or temporarily malformed
        // fare resource must not make an otherwise valid railway route vanish.
        let fareStations = (try? MTRStations.loadFareStations(airportExpress: false)) ?? []
        let fares = (try? MTRFares.load(airportExpress: false)) ?? [:]

        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let anchors = stationAnchors(stations: planner.stations, stops: stops)
        var destinationCandidates = anchors.compactMap { anchor -> StationCandidate? in
            guard let point = anchor.locations.min(by: {
                destinationLocation.distance(from: $0) < destinationLocation.distance(from: $1)
            }) else { return nil }
            let distance = destinationLocation.distance(from: point)
            return distance <= maximumWalkingDistance
                ? StationCandidate(station: anchor.station, location: point, distance: distance)
                : nil
        }
        .sorted { $0.distance < $1.distance }
        .prefix(4).map { $0 }

        if let id = preferredDestinationStationID,
           let station = planner.stations.first(where: { $0.id == id }) {
            destinationCandidates = [StationCandidate(
                station: station,
                location: destinationLocation,
                distance: 0
            )]
        }

        guard !destinationCandidates.isEmpty else { return [] }
        let fareIDs = Dictionary(uniqueKeysWithValues: fareStations.map { ($0.station.id, $0.fareID) })
        var results: [UniversalMTRJourney] = []

        // Walk directly to a nearby MTR station.
        var originCandidates = anchors.compactMap { anchor -> StationCandidate? in
            guard let point = anchor.locations.min(by: {
                originLocation.distance(from: $0) < originLocation.distance(from: $1)
            }) else { return nil }
            let distance = originLocation.distance(from: point)
            return distance <= maximumWalkingDistance
                ? StationCandidate(station: anchor.station, location: point, distance: distance)
                : nil
        }
        .sorted { $0.distance < $1.distance }
        .prefix(4).map { $0 }

        if let id = preferredOriginStationID,
           let station = planner.stations.first(where: { $0.id == id }) {
            originCandidates = [StationCandidate(
                station: station,
                location: originLocation,
                distance: 0
            )]
        }

        for start in originCandidates {
            for end in destinationCandidates where start.station.id != end.station.id {
                guard start.distance + end.distance <= maximumWalkingDistance,
                      let rail = planner.plan(from: start.station.id, to: end.station.id) else { continue }
                results.append(
                    UniversalMTRJourney(
                        feeder: nil,
                        railJourney: rail,
                        originStation: start.station,
                        destinationStation: end.station,
                        accessWalkDistance: start.distance,
                        transferWalkDistance: 0,
                        egressWalkDistance: end.distance,
                        fareCents: fare(
                            from: start.station.id,
                            to: end.station.id,
                            fareIDs: fareIDs,
                            fares: fares
                        )
                    )
                )
            }
        }

        // Connect a useful local feeder bus to an MTR station.
        let eligibleBusJourneys = preferredOriginStationID == nil
            ? journeys.filter {
                isOvernight($0) == (servicePeriod == .overnight)
                    && !isUnsuitableService($0)
            }
            : []
        for busJourney in eligibleBusJourneys {
            let ordered = busJourney.journeyStops.sorted { $0.sequence < $1.sequence }
            guard let boardingIndex = ordered.indices
                .filter({ index in
                    guard let stop = ordered[index].stop else { return false }
                    return originLocation.distance(from: location(stop)) <= maximumWalkingDistance
                })
                .min(by: { lhs, rhs in
                    originLocation.distance(from: location(ordered[lhs].stop!))
                        < originLocation.distance(from: location(ordered[rhs].stop!))
                }), let boardingStop = ordered[boardingIndex].stop else { continue }

            for alightingIndex in ordered.indices where alightingIndex > boardingIndex + 1 {
                guard let alightingStop = ordered[alightingIndex].stop,
                      let stationConnection = nearestStation(
                        to: location(alightingStop),
                        anchors: anchors,
                        maximumDistance: stationConnectionRadius
                      ) else { continue }

                for end in destinationCandidates where stationConnection.station.id != end.station.id {
                    guard let rail = planner.plan(
                        from: stationConnection.station.id,
                        to: end.station.id
                    ) else { continue }
                    let access = originLocation.distance(from: location(boardingStop))
                    let totalWalk = access + stationConnection.distance + end.distance
                    guard totalWalk <= maximumWalkingDistance else { continue }

                    results.append(
                        UniversalMTRJourney(
                            feeder: UniversalJourneyLeg(
                                journey: busJourney,
                                boarding: ordered[boardingIndex],
                                alighting: ordered[alightingIndex]
                            ),
                            railJourney: rail,
                            originStation: stationConnection.station,
                            destinationStation: end.station,
                            accessWalkDistance: access,
                            transferWalkDistance: stationConnection.distance,
                            egressWalkDistance: end.distance,
                            fareCents: fare(
                                from: stationConnection.station.id,
                                to: end.station.id,
                                fareIDs: fareIDs,
                                fares: fares
                            )
                        )
                    )
                }
                // One useful interchange station per feeder journey is enough.
                if results.contains(where: { $0.feeder?.journey.id == busJourney.id }) { break }
            }
        }

        var bestBySignature: [String: UniversalMTRJourney] = [:]
        for result in results {
            let feederNumber = result.feeder?.journey.route?.number.uppercased() ?? "walk"
            let lines = result.railJourney.legs.map(\.lineID).joined(separator: "-")
            let signature = "\(feederNumber)|\(result.originStation.id)|\(lines)|\(result.destinationStation.id)"
            if let current = bestBySignature[signature], current.totalMinutes <= result.totalMinutes {
                continue
            }
            bestBySignature[signature] = result
        }

        return bestBySignature.values.sorted {
            if $0.totalMinutes != $1.totalMinutes { return $0.totalMinutes < $1.totalMinutes }
            if $0.totalWalkDistance != $1.totalWalkDistance {
                return $0.totalWalkDistance < $1.totalWalkDistance
            }
            return ($0.totalFareCents ?? .max) < ($1.totalFareCents ?? .max)
        }
        .prefix(limit)
        .map { $0 }
    }

    private struct StationAnchor {
        let station: MTRStation
        let locations: [CLLocation]
    }

    private struct StationCandidate {
        let station: MTRStation
        let location: CLLocation
        let distance: CLLocationDistance
    }

    private static func stationAnchors(
        stations: [MTRStation],
        stops: [StopEntity]
    ) -> [StationAnchor] {
        stations.compactMap { station in
            let englishNeedle = "\(station.english.lowercased()) station"
            let traditionalNeedle = "\(station.traditional)站"
            let matching = stops.filter { stop in
                stop.displayNameEnglish.lowercased().contains(englishNeedle)
                    || stop.displayNameTraditional.contains(traditionalNeedle)
            }
            .map(location)
            guard !matching.isEmpty else { return nil }
            return StationAnchor(station: station, locations: matching)
        }
    }

    private static func nearestStation(
        to point: CLLocation,
        anchors: [StationAnchor],
        maximumDistance: CLLocationDistance
    ) -> StationCandidate? {
        anchors.compactMap { anchor -> StationCandidate? in
            guard let location = anchor.locations.min(by: {
                point.distance(from: $0) < point.distance(from: $1)
            }) else { return nil }
            let distance = point.distance(from: location)
            return distance <= maximumDistance
                ? StationCandidate(station: anchor.station, location: location, distance: distance)
                : nil
        }
        .min { $0.distance < $1.distance }
    }

    private static func fare(
        from: String,
        to: String,
        fareIDs: [String: Int],
        fares: [String: MTRAdultFare]
    ) -> Int? {
        guard let fromID = fareIDs[from], let toID = fareIDs[to],
              let fare = fares[MTRFares.key(from: fromID, to: toID)] else { return nil }
        return NSDecimalNumber(decimal: fare.octopus * 100).intValue
    }

    private static func location(_ stop: StopEntity) -> CLLocation {
        CLLocation(latitude: stop.latitude, longitude: stop.longitude)
    }

    private static func isOvernight(_ journey: JourneyEntity) -> Bool {
        let number = journey.route?.number.uppercased() ?? ""
        let service = journey.serviceType.lowercased()
        return number.hasPrefix("N") || service.contains("overnight") || service.contains("night service")
    }

    private static func isUnsuitableService(_ journey: JourneyEntity) -> Bool {
        let number = journey.route?.number.uppercased() ?? ""
        let text = [
            journey.route?.originEnglish ?? "",
            journey.route?.destinationEnglish ?? "",
            journey.serviceType
        ].joined(separator: " ").lowercased()
        return number.hasPrefix("A") || number.hasPrefix("NA") || number.hasPrefix("S")
            || ["cross-boundary", "huanggang", "shenzhen", "macao", "macau"]
                .contains(where: text.contains)
    }
}
