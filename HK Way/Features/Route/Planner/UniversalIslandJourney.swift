import Foundation

struct UniversalIslandJourney: Identifiable {
    let approach: UniversalMTRJourney
    let destination: IslandPlannerDestination
    let departure: IslandFerryDeparture

    var id: String { "\(approach.id)|ferry-\(destination.id)-\(departure.id)" }

    var departureTime: String {
        String(
            format: "%02d:%02d",
            departure.serviceMinutes / 60,
            departure.serviceMinutes % 60
        )
    }

    var totalMinutes: Int {
        let now = Date()
        let wait = max(0, Int(departure.departureDate.timeIntervalSince(now) / 60))
        return wait + (departure.referenceDurationMinutes ?? 35)
    }

    var routeSummary: String {
        let feeder = approach.feeder?.journey.route?.number
        let lines = approach.railJourney.legs.map(\.lineID)
        return ([feeder].compactMap { $0 } + lines + ["Ferry"]).joined(separator: " → ")
    }

    static func make(
        approach: UniversalMTRJourney,
        destination: IslandPlannerDestination
    ) -> UniversalIslandJourney? {
        let readyAt = Date.now.addingTimeInterval(TimeInterval((approach.totalMinutes + 5) * 60))
        guard let departure = try? IslandFerrySchedule.nextDeparture(
            to: destination,
            after: readyAt
        ) else { return nil }
        return UniversalIslandJourney(
            approach: approach,
            destination: destination,
            departure: departure
        )
    }
}
