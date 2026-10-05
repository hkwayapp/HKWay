import SwiftData
import SwiftUI

enum AirportPopularArea: String, CaseIterable, Identifiable {
    case tsimShaTsui
    case mongKok
    case causewayBay
    case tsuenWan
    case central
    case wanChai
    case shaTin
    case tuenMun

    var id: Self { self }

    var systemImage: String {
        return switch self {
        case .tsimShaTsui: "building.columns.fill"
        case .mongKok: "storefront.fill"
        case .causewayBay: "bag.fill"
        case .tsuenWan: "building.2.fill"
        case .central: "building.fill"
        case .wanChai: "building.2.fill"
        case .shaTin: "figure.walk"
        case .tuenMun: "water.waves"
        }
    }

    func title(for language: TransitLanguage) -> String {
        switch (self, language) {
        case (.tsimShaTsui, .english): "Tsim Sha Tsui"
        case (.mongKok, .english): "Mong Kok"
        case (.causewayBay, .english): "Causeway Bay"
        case (.tsuenWan, .english): "Tsuen Wan"
        case (.central, .english): "Central"
        case (.wanChai, .english): "Wan Chai"
        case (.shaTin, .english): "Sha Tin"
        case (.tuenMun, .english): "Tuen Mun"
        case (.tsimShaTsui, .traditionalChinese),
             (.tsimShaTsui, .simplifiedChinese): "尖沙咀"
        case (.mongKok, .traditionalChinese),
             (.mongKok, .simplifiedChinese): "旺角"
        case (.causewayBay, .traditionalChinese): "銅鑼灣"
        case (.causewayBay, .simplifiedChinese): "铜锣湾"
        case (.tsuenWan, .traditionalChinese): "荃灣"
        case (.tsuenWan, .simplifiedChinese): "荃湾"
        case (.central, .traditionalChinese): "中環"
        case (.central, .simplifiedChinese): "中环"
        case (.wanChai, .traditionalChinese): "灣仔"
        case (.wanChai, .simplifiedChinese): "湾仔"
        case (.shaTin, .traditionalChinese),
             (.shaTin, .simplifiedChinese): "沙田"
        case (.tuenMun, .traditionalChinese): "屯門"
        case (.tuenMun, .simplifiedChinese): "屯门"
        }
    }

    func matches(stop: StopEntity?) -> Bool {
        guard let stop else {
            return false
        }

        let name = stop.nameEnglish.lowercased()

        return switch self {
        case .tsimShaTsui: name.contains("tsim sha tsui")
        case .mongKok: name.contains("mong kok")
        case .causewayBay: name.contains("causeway bay")
        case .tsuenWan: name.contains("tsuen wan")
        case .central: name.contains("central")
        case .wanChai: name.contains("wan chai")
        case .shaTin: name.contains("sha tin")
        case .tuenMun: name.contains("tuen mun")
        }
    }
}

struct AirportPopularAreaRouteListView: View {
    let area: AirportPopularArea

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State private var matchingRoutes: [RouteEntity] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            CustomAppBackgroundView()

            Group {
            if isLoading {
                ProgressView("Loading routes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matchingRoutes.isEmpty {
                ContentUnavailableView(
                    "No Routes Found",
                    systemImage: area.systemImage,
                    description: Text("Update the dataset and try again.")
                )
            } else {
                List(matchingRoutes) { route in
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
        .navigationTitle(area.title(for: transitLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: area.id) {
            isLoading = true
            matchingRoutes = []
            await Task.yield()
            matchingRoutes = findMatchingRoutes()
            isLoading = false
        }
    }

    private func findMatchingRoutes() -> [RouteEntity] {
        routes
            .filter { route in
                AirportRouteGeography.servesAirport(route)
                    && route.journeys.contains { journey in
                        journey.journeyStops.contains { journeyStop in
                            area.matches(stop: journeyStop.stop)
                        }
                    }
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
}

#Preview {
    NavigationStack {
        AirportPopularAreaRouteListView(area: .tsimShaTsui)
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
