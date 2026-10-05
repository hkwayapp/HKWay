import SwiftUI
import SwiftData

enum AirportRouteCategory: String, CaseIterable, Identifiable {
    case a
    case e
    case night
    case s
    case db

    var id: Self { self }

    var displayCode: String {
        switch self {
        case .a: "A"
        case .e: "E"
        case .night: "NA / N"
        case .s: "S"
        case .db: "DB"
        }
    }

    func matches(routeNumber: String) -> Bool {
        let number = routeNumber.uppercased()

        switch self {
        case .a:
            return number.hasPrefix("A")
        case .e:
            return number.hasPrefix("E")
        case .night:
            return number.hasPrefix("NA") || number.hasPrefix("N")
        case .s:
            return number.hasPrefix("S")
        case .db:
            return number.hasPrefix("DB")
        }
    }

    func title(for language: TransitLanguage) -> String {
        switch self {
        case .a:
            language.localized("Direct Airport Routes")
        case .e:
            language.localized("External Airport Routes")
        case .night:
            language.localized("Overnight Routes")
        case .s:
            language.localized("Airport Shuttle Routes")
        case .db:
            language.localized("Discovery Bay Routes")
        }
    }

    func navigationTitle(for language: TransitLanguage) -> String {
        "\(descriptor(for: language)) – \(language.localized("\(displayCode) Routes"))"
    }

    private func descriptor(for language: TransitLanguage) -> String {
        switch self {
        case .a:
            language.localized("Direct Airport")
        case .e:
            language.localized("External Airport")
        case .night:
            language.localized("Overnight")
        case .s:
            language.localized("Airport Shuttle")
        case .db:
            language.localized("Discovery Bay")
        }
    }
}

struct AirportRouteListView: View {
    let category: AirportRouteCategory
    let area: AirportServiceArea?

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    private var airportRoutes: [RouteEntity] {
        routes
            .filter {
                category.matches(routeNumber: $0.number)
                    && AirportRouteGeography.servesAirport($0)
                    && matchesSelectedArea($0)
            }
            .sorted { lhs, rhs in
                let numberComparison = lhs.number
                    .localizedStandardCompare(rhs.number)

                if numberComparison != .orderedSame {
                    return numberComparison == .orderedAscending
                }

                return lhs.displayDestination(for: transitLanguage)
                    .localizedStandardCompare(
                        rhs.displayDestination(for: transitLanguage)
                    ) == .orderedAscending
            }
    }

    var body: some View {
        ZStack {
            CustomAppBackgroundView()

            Group {
            if airportRoutes.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "airplane",
                    description: Text(emptyDescription)
                )
            } else {
                List(airportRoutes) { route in
                    NavigationLink {
                        RouteDetailView(route: route)
                    } label: {
                        RouteRowView(
                            route: route,
                            etaResult: nil,
                            isCompact: true,
                            allowsTwoLineOrigin: true,
                            allowsTwoLineDestination: true,
                            allowsFullNameWrapping: true,
                            usesUniformNameStyle: true
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func matchesSelectedArea(_ route: RouteEntity) -> Bool {
        guard let area else {
            return true
        }

        return AirportRouteGeography.serviceAreas(for: route)
            .contains(area)
    }

    private var navigationTitle: String {
        guard let area else {
            return category.navigationTitle(
                for: transitLanguage
            )
        }

        return "\(category.navigationTitle(for: transitLanguage)) – \(area.title(for: transitLanguage))"
    }

    private var emptyTitle: String {
        transitLanguage.localized(
            "No \(category.displayCode) Airport Routes"
        )
    }

    private var emptyDescription: String {
        transitLanguage.localized(
            "Update the dataset and try again."
        )
    }
}

enum AirportRouteGeography {
    static func servesAirport(_ route: RouteEntity) -> Bool {
        route.journeys.contains { journey in
            journey.journeyStops.contains { journeyStop in
                isAirportStop(journeyStop.stop)
            }
        }
    }

    static func serviceAreas(
        for route: RouteEntity
    ) -> Set<AirportServiceArea> {
        Set(
            route.journeys.flatMap { journey in
                [journey.originStop, journey.destinationStop]
                    .compactMap { stop in
                        guard !isAirportStop(stop),
                              let regionId = stop?.regionId
                        else {
                            return nil
                        }

                        return AirportServiceArea(rawValue: regionId)
                    }
            }
        )
    }

    private static func isAirportStop(_ stop: StopEntity?) -> Bool {
        guard let stop else {
            return false
        }

        return stop.nameEnglish.localizedCaseInsensitiveContains(
            "airport"
        )
    }
}

#Preview {
    NavigationStack {
        AirportRouteListView(category: .a, area: nil)
    }
    .modelContainer(
        for: [
            RouteEntity.self,
            JourneyEntity.self,
            JourneyStopEntity.self,
            StopEntity.self,
            OperatorEntity.self
        ],
        inMemory: true
    )
}
