import Foundation

struct WatchJourney: Codable, Identifiable, Hashable {
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
    let etaReferences: [WatchETAReference]?
    let upcomingStops: [WatchJourneyStop]?
    let boardingSequence: Int?

    var destination: String {
        localized(
            english: destinationEnglish,
            traditional: destinationTraditional,
            simplified: destinationSimplified
        )
    }

    var boardingStop: String {
        localized(
            english: stopEnglish,
            traditional: stopTraditional,
            simplified: stopSimplified
        )
    }

    var futureArrivals: [Date] {
        arrivalDates.filter { $0 > .now }.sorted()
    }

    private func localized(
        english: String,
        traditional: String,
        simplified: String
    ) -> String {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("zh-Hans") { return simplified }
        if language.hasPrefix("zh") { return traditional }
        return english
    }
}

struct WatchJourneyStop: Codable, Hashable {
    let sequence: Int
    let english: String
    let traditional: String
    let simplified: String
    let latitude: Double?
    let longitude: Double?

    var name: String {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("zh-Hans") { return simplified }
        if language.hasPrefix("zh") { return traditional }
        return english
    }
}

struct WatchETAReference: Codable, Hashable {
    let operatorId: String
    let operatorStopId: String
    let operatorServiceType: String
    let operatorDirection: String
}
