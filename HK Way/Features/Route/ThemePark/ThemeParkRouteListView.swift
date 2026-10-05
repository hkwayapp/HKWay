import SwiftUI
import SwiftData

struct ThemeParkRouteListView: View {
    let destination: ThemeParkDestination

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State private var matchingRoutes: [RouteEntity] = []
    @State private var isLoading = true

    private func findMatchingRoutes() -> [RouteEntity] {
        routes
            .filter { route in
                route.journeys.contains { journey in
                    journey.journeyStops.contains { journeyStop in
                        guard let stop = journeyStop.stop else {
                            return false
                        }

                        return destination.matches(stop: stop)
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

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading routes...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matchingRoutes.isEmpty {
                ContentUnavailableView(
                    noRoutesTitle,
                    systemImage: destination.systemImage,
                    description: Text(
                        transitLanguage.localized(
                            "Update the dataset and try again."
                        )
                    )
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
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)
            }
        }
        .background(destination.accent.opacity(0.10).ignoresSafeArea())
        .navigationTitle(
            destination.title(for: transitLanguage)
        )
        .navigationBarTitleDisplayMode(.inline)
        .task(id: destination.id) {
            isLoading = true
            matchingRoutes = []

            // Let navigation finish and render the progress message
            // before walking the route and stop relationships.
            await Task.yield()

            matchingRoutes = findMatchingRoutes()
            isLoading = false
        }
    }

    private var noRoutesTitle: String {
        transitLanguage.localized("No Theme Park Routes")
    }
}

#Preview {
    NavigationStack {
        ThemeParkRouteListView(destination: .disneyland)
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
