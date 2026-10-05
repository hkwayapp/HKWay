import SwiftData
import SwiftUI

enum PeakTramConnectionPoint: String, CaseIterable, Identifiable {
    case centralTerminus
    case peakTerminus

    var id: Self { self }

    var systemImage: String {
        return switch self {
        case .centralTerminus: "building.2.fill"
        case .peakTerminus: "mountain.2.fill"
        }
    }

    func title(for language: TransitLanguage) -> String {
        switch self {
        case .centralTerminus:
            language.localized("Garden Road Connections")
        case .peakTerminus:
            language.localized("Peak Terminus")
        }
    }

    func matches(_ stop: StopEntity?) -> Bool {
        guard let stop else { return false }

        let name = stop.nameEnglish.lowercased()

        return switch self {
        case .centralTerminus:
            name.contains("peak tram central terminus")
                || name.contains("garden road peak tram")
                || name.contains("garden road (peak tram")
                || name.contains("st. john's cathedral")
                || name.contains("st john's cathedral")
        case .peakTerminus:
            name == "the peak"
                || name.contains("the peak terminus")
                || name.contains("peak galleria")
        }
    }
}

struct PeakTramConnectingRoutesView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    @Environment(\.transitLanguage)
    private var transitLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose a Peak Tram connection point")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PeakTramConnectionPoint.allCases) { point in
                        NavigationLink {
                            PeakTramConnectionRouteListView(point: point)
                        } label: {
                            CustomInfoCardView(title: "") {
                                VStack(spacing: 8) {
                                    Image(systemName: point.systemImage)
                                        .font(.title2)

                                    Text(point.title(for: transitLanguage))
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Label(
                    "Routes are grouped by whether the selected connection point is the route endpoint or an intermediate stop.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding()
        }
        .navigationTitle("Connecting Routes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PeakTramConnectionRouteListView: View {
    let point: PeakTramConnectionPoint

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State
    private var directRoutes: [RouteEntity] = []

    @State
    private var passByRoutes: [RouteEntity] = []

    @State
    private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading connecting routes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if directRoutes.isEmpty && passByRoutes.isEmpty {
                ContentUnavailableView(
                    "No Connecting Routes",
                    systemImage: point.systemImage,
                    description: Text("Update the dataset and try again.")
                )
            } else {
                List {
                    if !directRoutes.isEmpty {
                        Section("Direct / Terminates Here") {
                            routeRows(directRoutes)
                        }
                    }

                    if !passByRoutes.isEmpty {
                        Section("Pass-by Routes") {
                            routeRows(passByRoutes)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(point.title(for: transitLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: point.id) {
            isLoading = true
            directRoutes = []
            passByRoutes = []
            await Task.yield()

            let matches = findMatchingRoutes()
            directRoutes = matches.direct
            passByRoutes = matches.passBy
            isLoading = false
        }
    }

    @ViewBuilder
    private func routeRows(_ routes: [RouteEntity]) -> some View {
        ForEach(routes) { route in
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
    }

    private func findMatchingRoutes() -> (
        direct: [RouteEntity],
        passBy: [RouteEntity]
    ) {
        var direct: [RouteEntity] = []
        var passBy: [RouteEntity] = []

        for route in routes {
            var servesPoint = false
            var terminatesAtPoint = false

            for journey in route.journeys {
                let orderedStops = journey.journeyStops.sorted {
                    $0.sequence < $1.sequence
                }

                guard orderedStops.contains(where: {
                    point.matches($0.stop)
                }) else {
                    continue
                }

                servesPoint = true

                if point.matches(journey.originStop)
                    || point.matches(journey.destinationStop)
                    || point.matches(orderedStops.first?.stop)
                    || point.matches(orderedStops.last?.stop) {
                    terminatesAtPoint = true
                }
            }

            if terminatesAtPoint {
                direct.append(route)
            } else if servesPoint {
                passBy.append(route)
            }
        }

        return (sort(direct), sort(passBy))
    }

    private func sort(_ routes: [RouteEntity]) -> [RouteEntity] {
        routes.sorted { lhs, rhs in
            let numberComparison = lhs.number.localizedStandardCompare(
                rhs.number
            )

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
        PeakTramConnectingRoutesView()
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
