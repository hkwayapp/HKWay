//
//  UniversalJourneyRouter.swift
//  HK Way
//

import CoreLocation
import Foundation

enum PlannerServicePeriod: String, CaseIterable, Identifiable {
    case normal
    case overnight

    var id: Self { self }
}

struct UniversalJourneyLeg: Identifiable {
    let journey: JourneyEntity
    let boarding: JourneyStopEntity
    let alighting: JourneyStopEntity

    var id: String { "\(journey.id)-\(boarding.sequence)-\(alighting.sequence)" }
    var stopCount: Int { max(0, alighting.sequence - boarding.sequence) }
    var adultFareCents: Int? { journey.boardingFareCents(at: boarding.sequence) }

    var estimatedMinutes: Int {
        let ordered = journey.journeyStops.sorted { $0.sequence < $1.sequence }
        let fullStopCount = max(
            1,
            (ordered.last?.sequence ?? 1) - (ordered.first?.sequence ?? 0)
        )
        if let scheduled = journey.scheduledDurationMinutes, scheduled > 0 {
            return max(1, Int((Double(scheduled) * Double(stopCount) / Double(fullStopCount)).rounded()))
        }
        return max(2, stopCount * 2)
    }
}

struct UniversalPlannedJourney: Identifiable {
    let legs: [UniversalJourneyLeg]
    var routePreference = 0
    var accessWalkDistance: CLLocationDistance
    var accessWalkMinutes: Int
    var transferWalkDistance: CLLocationDistance
    var transferWalkMinutes: Int
    var egressWalkDistance: CLLocationDistance
    var egressWalkMinutes: Int

    var id: String { legs.map(\.id).joined(separator: "|") }
    var displaySignature: String {
        legs.map { leg in
            let routeNumber = leg.journey.route?.number.uppercased() ?? leg.journey.id
            let operators = leg.journey.route?.operators.map(\.id).sorted().joined(separator: ",") ?? ""
            return "\(operators):\(routeNumber)"
        }
        .joined(separator: "|")
    }
    var transferCount: Int { max(0, legs.count - 1) }
    var totalFareCents: Int? {
        let fares = legs.compactMap(\.adultFareCents)
        return fares.count == legs.count ? fares.reduce(0, +) : nil
    }
    var totalWalkDistance: CLLocationDistance {
        accessWalkDistance + transferWalkDistance + egressWalkDistance
    }
    var totalMinutes: Int {
        accessWalkMinutes + transferWalkMinutes + egressWalkMinutes
            + legs.reduce(0) { $0 + $1.estimatedMinutes }
            + transferCount * 5
    }
}

@MainActor
enum UniversalJourneyRouter {
    private static let accessRadius: CLLocationDistance = 1_200
    private static let destinationRadius: CLLocationDistance = 900
    private static let walkingMetresPerMinute = 75.0

    static func journeys(
        from origin: UniversalPlannerEndpoint,
        to destination: UniversalPlannerEndpoint,
        originCoordinate resolvedOriginCoordinate: CLLocationCoordinate2D? = nil,
        destinationCoordinate resolvedDestinationCoordinate: CLLocationCoordinate2D? = nil,
        stops allStops: [StopEntity],
        journeys: [JourneyEntity],
        servicePeriod: PlannerServicePeriod,
        limit: Int = 20
    ) -> [UniversalPlannedJourney] {
        guard let originCoordinate = resolvedOriginCoordinate ?? origin.coordinate,
              let destinationCoordinate = resolvedDestinationCoordinate ?? destination.coordinate else { return [] }

        let policy = DestinationRoutePolicy(destination: destination)
        let eligibleJourneys = journeys.filter {
            !isCrossBoundaryService($0)
                && isOvernightService($0) == (servicePeriod == .overnight)
        }
        let searchJourneys = eligibleJourneys.sorted {
            policy.firstLegPriority($0) < policy.firstLegPriority($1)
        }

        let accessStops = nearbyStops(to: originCoordinate, stops: allStops, radius: accessRadius)
        let destinationStops = nearbyStops(to: destinationCoordinate, stops: allStops, radius: destinationRadius)
        guard !accessStops.isEmpty, !destinationStops.isEmpty else { return [] }

        var results = directJourneys(
            accessStops: accessStops,
            destinationStops: destinationStops,
            journeys: searchJourneys
        )
        if results.count < limit {
            results.append(contentsOf: oneTransferJourneys(
                accessStops: accessStops,
                destinationStops: destinationStops,
                allStops: allStops,
                journeys: searchJourneys,
                resultLimit: max(limit * 8, 120)
            ))
        }

        let preferred = results
            .filter { policy.allows($0) }
            .compactMap { journey -> UniversalPlannedJourney? in
                guard let qualityPenalty = qualityPenalty(
                    for: journey,
                    origin: originCoordinate,
                    destination: destinationCoordinate
                ) else { return nil }
                var preferred = journey
                preferred.routePreference = policy.priority(journey) * 1_000 + qualityPenalty
                return preferred
            }

        var bestByDisplayedRoute: [String: UniversalPlannedJourney] = [:]
        for journey in preferred {
            if let current = bestByDisplayedRoute[journey.displaySignature],
               preferredOrder(current, journey, policy: policy) {
                continue
            }
            bestByDisplayedRoute[journey.displaySignature] = journey
        }

        return bestByDisplayedRoute.values
            .sorted { preferredOrder($0, $1, policy: policy) }
            .prefix(limit)
            .map { $0 }
    }

    private static func directJourneys(
        accessStops: [String: CLLocationDistance],
        destinationStops: [String: CLLocationDistance],
        journeys: [JourneyEntity]
    ) -> [UniversalPlannedJourney] {
        journeys.compactMap { journey in
            let ordered = journey.journeyStops.sorted { $0.sequence < $1.sequence }
            guard let boardingIndex = ordered.indices
                .filter({ accessStops[ordered[$0].stop?.id ?? ""] != nil })
                .min(by: { lhs, rhs in
                    accessStops[ordered[lhs].stop!.id]! < accessStops[ordered[rhs].stop!.id]!
                }),
                let alightingIndex = ordered.indices
                    .filter({ $0 > boardingIndex && destinationStops[ordered[$0].stop?.id ?? ""] != nil })
                    .min(by: { lhs, rhs in
                        destinationStops[ordered[lhs].stop!.id]! < destinationStops[ordered[rhs].stop!.id]!
                    }) else { return nil }

            let boarding = ordered[boardingIndex]
            let alighting = ordered[alightingIndex]
            guard let boardingID = boarding.stop?.id,
                  let alightingID = alighting.stop?.id else { return nil }
            return plannedJourney(
                legs: [.init(journey: journey, boarding: boarding, alighting: alighting)],
                accessDistance: accessStops[boardingID] ?? 0,
                transferDistance: 0,
                egressDistance: destinationStops[alightingID] ?? 0
            )
        }
    }

    private static func oneTransferJourneys(
        accessStops: [String: CLLocationDistance],
        destinationStops: [String: CLLocationDistance],
        allStops: [StopEntity],
        journeys: [JourneyEntity],
        resultLimit: Int
    ) -> [UniversalPlannedJourney] {
        typealias IndexedService = (journey: JourneyEntity, index: Int, stops: [JourneyStopEntity])
        var servicesByStop: [String: [IndexedService]] = [:]
        for journey in journeys {
            let ordered = journey.journeyStops.sorted { $0.sequence < $1.sequence }
            for (index, journeyStop) in ordered.enumerated() {
                guard let id = journeyStop.stop?.id else { continue }
                servicesByStop[id, default: []].append((journey, index, ordered))
            }
        }

        struct GridCell: Hashable {
            let latitude: Int
            let longitude: Int
        }
        let gridScale = 400.0
        var locationsByStop: [String: CLLocation] = [:]
        var stopIDsByCell: [GridCell: [String]] = [:]
        for stop in allStops where servicesByStop[stop.id] != nil {
            let location = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            locationsByStop[stop.id] = location
            let cell = GridCell(
                latitude: Int((stop.latitude * gridScale).rounded(.down)),
                longitude: Int((stop.longitude * gridScale).rounded(.down))
            )
            stopIDsByCell[cell, default: []].append(stop.id)
        }

        func nearbyTransferStops(_ stopID: String) -> [(id: String, distance: CLLocationDistance)] {
            guard let location = locationsByStop[stopID] else { return [(stopID, 0)] }
            let center = GridCell(
                latitude: Int((location.coordinate.latitude * gridScale).rounded(.down)),
                longitude: Int((location.coordinate.longitude * gridScale).rounded(.down))
            )
            var matches: [(String, CLLocationDistance)] = []
            for latitudeOffset in -1...1 {
                for longitudeOffset in -1...1 {
                    let cell = GridCell(
                        latitude: center.latitude + latitudeOffset,
                        longitude: center.longitude + longitudeOffset
                    )
                    for candidateID in stopIDsByCell[cell] ?? [] {
                        guard let candidate = locationsByStop[candidateID] else { continue }
                        let distance = location.distance(from: candidate)
                        if distance <= 300 { matches.append((candidateID, distance)) }
                    }
                }
            }
            return matches.sorted { $0.1 < $1.1 }
        }

        var results: [UniversalPlannedJourney] = []
        for firstJourney in journeys {
            if results.count >= resultLimit { break }
            let firstStops = firstJourney.journeyStops.sorted { $0.sequence < $1.sequence }
            guard let boardingIndex = firstStops.indices
                .filter({ accessStops[firstStops[$0].stop?.id ?? ""] != nil })
                .min(by: { lhs, rhs in
                    accessStops[firstStops[lhs].stop!.id]! < accessStops[firstStops[rhs].stop!.id]!
                }) else { continue }

            for transferIndex in firstStops.indices where transferIndex > boardingIndex {
                guard results.count < resultLimit,
                      let transferID = firstStops[transferIndex].stop?.id else { continue }
                for transfer in nearbyTransferStops(transferID) {
                    guard let onwardServices = servicesByStop[transfer.id] else { continue }
                    for onward in onwardServices where onward.journey.id != firstJourney.id {
                        guard let alightingIndex = onward.stops.indices
                            .filter({ $0 > onward.index && destinationStops[onward.stops[$0].stop?.id ?? ""] != nil })
                            .min(by: { lhs, rhs in
                                destinationStops[onward.stops[lhs].stop!.id]!
                                    < destinationStops[onward.stops[rhs].stop!.id]!
                            }),
                            let boardingID = firstStops[boardingIndex].stop?.id,
                            let alightingID = onward.stops[alightingIndex].stop?.id else { continue }

                        results.append(plannedJourney(
                            legs: [
                                .init(journey: firstJourney, boarding: firstStops[boardingIndex], alighting: firstStops[transferIndex]),
                                .init(journey: onward.journey, boarding: onward.stops[onward.index], alighting: onward.stops[alightingIndex])
                            ],
                            accessDistance: accessStops[boardingID] ?? 0,
                            transferDistance: transfer.distance,
                            egressDistance: destinationStops[alightingID] ?? 0
                        ))
                        if results.count >= resultLimit { break }
                    }
                    if results.count >= resultLimit { break }
                }
            }
        }
        return results
    }

    private static func nearbyStops(
        to coordinate: CLLocationCoordinate2D,
        stops: [StopEntity],
        radius: CLLocationDistance
    ) -> [String: CLLocationDistance] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return stops.reduce(into: [:]) { result, stop in
            let coordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return }
            let distance = location.distance(from: CLLocation(latitude: stop.latitude, longitude: stop.longitude))
            if distance <= radius { result[stop.id] = distance }
        }
    }

    private static func plannedJourney(
        legs: [UniversalJourneyLeg],
        accessDistance: CLLocationDistance,
        transferDistance: CLLocationDistance,
        egressDistance: CLLocationDistance
    ) -> UniversalPlannedJourney {
        UniversalPlannedJourney(
            legs: legs,
            accessWalkDistance: accessDistance,
            accessWalkMinutes: walkingMinutes(for: accessDistance),
            transferWalkDistance: transferDistance,
            transferWalkMinutes: walkingMinutes(for: transferDistance),
            egressWalkDistance: egressDistance,
            egressWalkMinutes: walkingMinutes(for: egressDistance)
        )
    }

    private static func walkingMinutes(for distance: CLLocationDistance) -> Int {
        distance < 25 ? 0 : max(1, Int(ceil(distance / walkingMetresPerMinute)))
    }

    private static func preferredOrder(
        _ lhs: UniversalPlannedJourney,
        _ rhs: UniversalPlannedJourney,
        policy: DestinationRoutePolicy
    ) -> Bool {
        if lhs.routePreference != rhs.routePreference {
            return lhs.routePreference < rhs.routePreference
        }
        let leftPriority = policy.priority(lhs)
        let rightPriority = policy.priority(rhs)
        if leftPriority != rightPriority { return leftPriority < rightPriority }
        if lhs.totalMinutes != rhs.totalMinutes { return lhs.totalMinutes < rhs.totalMinutes }
        if lhs.transferCount != rhs.transferCount { return lhs.transferCount < rhs.transferCount }
        if lhs.totalWalkDistance != rhs.totalWalkDistance { return lhs.totalWalkDistance < rhs.totalWalkDistance }
        return (lhs.totalFareCents ?? Int.max) < (rhs.totalFareCents ?? Int.max)
    }

    /// Returns nil for geographically unreasonable itineraries. Otherwise the
    /// value is a universal quality penalty used ahead of rough time estimates.
    private static func qualityPenalty(
        for journey: UniversalPlannedJourney,
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) -> Int? {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let directDistance = max(1, originLocation.distance(from: destinationLocation))
        var travelledDistance = journey.totalWalkDistance
        var penalty = journey.transferCount * 8

        // A transfer should produce a meaningful transit journey. Two tiny
        // bus legs followed by a long walk are generally worse than walking
        // to a stronger direct service.
        if journey.transferCount > 0 {
            let travelledStops = journey.legs.reduce(0) { $0 + $1.stopCount }
            if travelledStops <= 8, journey.totalWalkDistance > 700 { return nil }
            if journey.egressWalkDistance > 850, travelledStops <= 12 { return nil }
        }

        for leg in journey.legs {
            guard let boardingStop = leg.boarding.stop,
                  let alightingStop = leg.alighting.stop else { return nil }
            let boardingLocation = location(boardingStop)
            let alightingLocation = location(alightingStop)
            let boardingToDestination = boardingLocation.distance(from: destinationLocation)
            let alightingToDestination = alightingLocation.distance(from: destinationLocation)

            // A useful feeder can initially move sideways, but a service that
            // carries the passenger several kilometres away is not reasonable.
            let backwardDistance = alightingToDestination - boardingToDestination
            if backwardDistance > max(4_000, directDistance * 0.45) { return nil }
            if backwardDistance > max(900, directDistance * 0.12) {
                penalty += Int(min(40, backwardDistance / 250))
            }

            let pathDistance = journeyPathDistance(for: leg)
            travelledDistance += pathDistance
            let straightLegDistance = max(1, boardingLocation.distance(from: alightingLocation))
            let legDetourRatio = pathDistance / straightLegDistance
            if straightLegDistance > 1_500, legDetourRatio > 5 { return nil }
            if legDetourRatio > 2.5 {
                penalty += Int(min(30, (legDetourRatio - 2.5) * 8))
            }

            penalty += specialServicePenalty(for: leg.journey)
        }

        // Allow winding roads and harbour crossings, while rejecting paths
        // that are far longer than the actual origin-to-destination journey.
        if directDistance > 2_000,
           travelledDistance > directDistance * 3.6 + 3_000 {
            return nil
        }
        if travelledDistance > directDistance * 2.1 + 1_500 {
            penalty += Int(min(45, (travelledDistance / directDistance - 2.1) * 12))
        }

        penalty += Int(min(25, journey.totalWalkDistance / 250))
        return penalty
    }

    /// Apple Maps can return a substantially longer walk than the initial
    /// straight-line estimate because of estates, highways or restricted
    /// crossings. Remove the result after refinement when that happens.
    static func acceptsRefinedWalking(_ journey: UniversalPlannedJourney) -> Bool {
        if journey.accessWalkDistance > 1_500 { return false }
        if journey.egressWalkDistance > 1_200 { return false }
        if journey.transferWalkDistance > 500 { return false }
        if journey.totalWalkDistance > 2_000 { return false }

        if journey.transferCount > 0 {
            let travelledStops = journey.legs.reduce(0) { $0 + $1.stopCount }
            if travelledStops <= 8, journey.totalWalkDistance > 700 { return false }
            if travelledStops <= 12, journey.egressWalkDistance > 850 { return false }
        }
        return true
    }

    private static func journeyPathDistance(for leg: UniversalJourneyLeg) -> CLLocationDistance {
        let stops = leg.journey.journeyStops
            .filter { $0.sequence >= leg.boarding.sequence && $0.sequence <= leg.alighting.sequence }
            .sorted { $0.sequence < $1.sequence }
            .compactMap(\.stop)
        guard stops.count > 1 else { return 0 }
        return zip(stops, stops.dropFirst()).reduce(0) { total, pair in
            total + location(pair.0).distance(from: location(pair.1))
        }
    }

    private static func location(_ stop: StopEntity) -> CLLocation {
        CLLocation(latitude: stop.latitude, longitude: stop.longitude)
    }

    private static func specialServicePenalty(for journey: JourneyEntity) -> Int {
        let service = journey.serviceType.lowercased()
        let specialTerms = [
            "special", "limited", "overnight", "night", "event",
            "racecourse", "school", "holiday", "peak only"
        ]
        var penalty = specialTerms.contains(where: service.contains) ? 24 : 0
        let number = journey.route?.number.uppercased() ?? ""
        if number.hasPrefix("N") || number.hasSuffix("P") || number.hasSuffix("S") {
            penalty += 10
        }
        return penalty
    }

    private static func isOvernightService(_ journey: JourneyEntity) -> Bool {
        let number = journey.route?.number.uppercased() ?? ""
        let service = journey.serviceType.lowercased()
        return number.hasPrefix("N")
            || service.contains("overnight")
            || service.contains("night service")
    }

    private static func isCrossBoundaryService(_ journey: JourneyEntity) -> Bool {
        guard let route = journey.route else { return false }
        let text = [
            route.number,
            route.originEnglish,
            route.destinationEnglish,
            journey.serviceType
        ]
        .joined(separator: " ")
        .lowercased()

        let crossBoundaryTerms = [
            "cross-boundary", "cross boundary", "huanggang", "shenzhen",
            "zhuhai", "macao", "macau", "mainland china"
        ]
        return crossBoundaryTerms.contains(where: text.contains)
    }

    private enum DestinationRoutePolicy {
        case airport
        case disneyland
        case standard

        init(destination: UniversalPlannerEndpoint) {
            let name = destination.title(language: .english)
            if name.localizedCaseInsensitiveContains("Disneyland") {
                self = .disneyland
            } else if name.localizedCaseInsensitiveContains("Airport") {
                self = .airport
            } else {
                self = .standard
            }
        }

        func allows(_ journey: UniversalPlannedJourney) -> Bool {
            guard let finalNumber = journey.legs.last?.journey.route?.number.uppercased() else {
                return false
            }
            let routeNumbers = journey.legs.compactMap {
                $0.journey.route?.number.uppercased()
            }
            switch self {
            case .airport:
                return Self.isAirportRoute(finalNumber)
            case .disneyland:
                return true
            case .standard:
                // Premium airport and airport-shuttle routes should not be
                // proposed as ordinary local feeder services.
                return !routeNumbers.contains(where: Self.isPremiumAirportRoute)
            }
        }

        func priority(_ journey: UniversalPlannedJourney) -> Int {
            let numbers = journey.legs.compactMap { $0.journey.route?.number.uppercased() }
            switch self {
            case .airport:
                if numbers.last.map(Self.isAirportRoute) == true { return 0 }
                return 100
            case .disneyland:
                if numbers.last == "R8" && numbers.dropLast().contains(where: Self.isAirportRoute) {
                    return 0
                }
                if numbers.last == "R8" { return 1 }
                if numbers.contains(where: { $0.hasPrefix("R") }) { return 20 }
                return 10
            case .standard:
                return 0
            }
        }

        func firstLegPriority(_ journey: JourneyEntity) -> Int {
            let number = journey.route?.number.uppercased() ?? ""
            switch self {
            case .disneyland:
                return Self.isAirportRoute(number) ? 0 : number == "R8" ? 1 : 2
            case .airport:
                return Self.isAirportRoute(number) ? 0 : 1
            case .standard:
                return 0
            }
        }

        private static func isAirportRoute(_ number: String) -> Bool {
            number.hasPrefix("A")
                || number.hasPrefix("E")
                || number.hasPrefix("NA")
                || number.hasPrefix("N")
                || number.hasPrefix("S")
        }


        private static func isPremiumAirportRoute(_ number: String) -> Bool {
            number.hasPrefix("A")
                || number.hasPrefix("NA")
                || number.hasPrefix("S")
        }
    }
}
