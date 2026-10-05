import SwiftUI
import SwiftData
import MapKit

struct FavoriteStopDetailView: View {

    let stop: StopEntity

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(PurchaseManager.self)
    private var purchaseManager

    @AppStorage("favoriteStopIds")
    private var favoriteStopIdsValue = ""

    @State
    private var showsFavoriteStopLimit = false

    @State
    private var routeMatches: [FavoriteStopRouteMatch] = []

    @State
    private var etaResults: [String: RouteETAResult] = [:]

    @State
    private var loadingMatchIds: Set<String> = []

    @State
    private var unavailableMatchIds: Set<String> = []

    @State
    private var failedMatchIds: Set<String> = []

    private var coordinate: CLLocationCoordinate2D {
        let corrected = StopCoordinateCorrection.values(
            stopID: stop.id,
            latitude: stop.latitude,
            longitude: stop.longitude
        )
        return CLLocationCoordinate2D(
            latitude: corrected.latitude,
            longitude: corrected.longitude
        )
    }

    private var mapPosition: MapCameraPosition {
        .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.005,
                    longitudeDelta: 0.005
                )
            )
        )
    }

    private var favoriteStopIds: Set<String> {
        Set(
            favoriteStopIdsValue
                .split(separator: "\n")
                .map(String.init)
        )
    }

    private var isFavorite: Bool {
        favoriteStopIds.contains(stop.id)
    }

    private var operatorIds: [String] {
        Array(
            Set(
                routeMatches.flatMap { match in
                    match.route.operators.flatMap { operatorEntity in
                        operatorEntity.id
                            .split(separator: "+")
                            .map(String.init)
                    }
                }
            )
        )
        .sorted()
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Map(
                        initialPosition: mapPosition,
                        interactionModes: [.pan, .zoom]
                    ) {
                        Marker(
                            stop.displayName(for: transitLanguage),
                            coordinate: coordinate
                        )
                    }
                    .frame(height: 260)

                    CustomLookAroundPreviewView(
                        coordinate: coordinate
                    )
                }
                .listRowInsets(EdgeInsets())
            }

            Section("Routes") {
                if routeMatches.isEmpty {
                    Text("No routes serve this stop")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(routeMatches) { match in
                        NavigationLink {
                            RouteDetailView(route: match.route)
                        } label: {
                            RouteRowView(
                                route: match.route,
                                destination:
                                    match.destination(
                                        for: transitLanguage
                                ),
                                etaResult: etaResults[match.id],
                                isLoadingETA: loadingMatchIds
                                    .contains(match.id),
                                isETAUnavailable: unavailableMatchIds
                                    .contains(match.id),
                                didETAFail: failedMatchIds
                                    .contains(match.id),
                                isCompact: true,
                                showsDistance: false,
                                allowsTwoLineOrigin: true,
                                allowsTwoLineDestination: true
                            )
                            .environment(
                                \.locale,
                                transitLanguage.locale
                            )
                            .task(id: match.id) {
                                await refreshETA(for: match)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            CustomOperatorBackgroundView(
                operatorIds: operatorIds
            )
        }
        .navigationTitle(
            stop.displayName(for: transitLanguage)
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(
                        systemName: isFavorite
                            ? "bookmark.fill"
                            : "bookmark"
                    )
                }
                .accessibilityLabel(
                    isFavorite
                        ? "Remove from Favorites"
                        : "Add to Favorites"
                )
            }
        }
        .alert(
            "Favorite Bus Stop Limit Reached",
            isPresented: $showsFavoriteStopLimit
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Free allows up to 5 favorite bus stops. Remove one before adding another, or upgrade to Full for unlimited favorites.")
        }
        .task {
            loadRoutes()
        }
    }

    private func refreshETA(
        for match: FavoriteStopRouteMatch
    ) async {
        while !Task.isCancelled {
            await loadETA(
                for: match,
                forceRefresh: etaResults[match.id] != nil
            )

            do {
                try await Task.sleep(
                    for: ETARefreshCoordinator.refreshInterval
                )
            } catch {
                return
            }
        }
    }

    @MainActor
    private func loadRoutes() {
        let stopId = stop.id
        let descriptor = FetchDescriptor<JourneyStopEntity>(
            predicate: #Predicate {
                $0.stop?.id == stopId
            }
        )

        guard let journeyStops = try? modelContext.fetch(descriptor) else {
            routeMatches = []
            return
        }

        var uniqueMatches: [String: FavoriteStopRouteMatch] = [:]

        for candidate in journeyStops {
            guard
                let journey = candidate.journey,
                let route = journey.route
            else {
                continue
            }

            let key = [
                route.id,
                journey.direction,
                journey.destinationStop?.id ?? ""
            ].joined(separator: "|")

            if uniqueMatches[key] == nil {
                uniqueMatches[key] = FavoriteStopRouteMatch(
                    id: key,
                    route: route,
                    journey: journey,
                    journeyStop: candidate
                )
            }
        }

        routeMatches = uniqueMatches.values.sorted { lhs, rhs in
            let comparison = lhs.route.number
                .localizedStandardCompare(rhs.route.number)

            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            return lhs.destination(for: transitLanguage)
                .localizedStandardCompare(
                    rhs.destination(for: transitLanguage)
                ) == .orderedAscending
        }
    }

    @MainActor
    private func loadETA(
        for match: FavoriteStopRouteMatch,
        forceRefresh: Bool
    ) async {
        guard
            forceRefresh || etaResults[match.id] == nil,
            !loadingMatchIds.contains(match.id)
        else {
            return
        }

        loadingMatchIds.insert(match.id)
        unavailableMatchIds.remove(match.id)
        failedMatchIds.remove(match.id)

        let coordinator = ETARefreshCoordinator.shared
        await coordinator.acquire()

        guard !Task.isCancelled else {
            loadingMatchIds.remove(match.id)
            await coordinator.release()
            return
        }

        do {
            let result = try await RouteETAResolver().resolve(
                journey: match.journey,
                journeyStop: match.journeyStop,
                modelContext: modelContext
            )

            if !Task.isCancelled {
                if let result {
                    etaResults[match.id] = result
                    TransitWidgetSnapshotStore.save(
                        TransitWidgetSnapshot(
                            route: match.route,
                            result: result,
                            id: "\(stop.id)|\(match.id)"
                        )
                    )
                } else if etaResults[match.id] == nil {
                    unavailableMatchIds.insert(match.id)
                }
            }
        } catch {
            if !Task.isCancelled,
               etaResults[match.id] == nil {
                failedMatchIds.insert(match.id)
            }
        }

        loadingMatchIds.remove(match.id)
        await coordinator.release()
    }

    private func toggleFavorite() {
        var ids = favoriteStopIds

        if isFavorite {
            ids.remove(stop.id)
        } else {
            let policy = AppAccessPolicy(tier: purchaseManager.accessTier)
            guard policy.allowsAddition(
                to: .favoriteBusStops,
                existingCount: ids.count,
                isAlreadySaved: false
            ) else {
                showsFavoriteStopLimit = true
                return
            }
            ids.insert(stop.id)
        }

        favoriteStopIdsValue = ids.sorted()
            .joined(separator: "\n")
    }
}

private struct FavoriteStopRouteMatch: Identifiable {
    let id: String
    let route: RouteEntity
    let journey: JourneyEntity
    let journeyStop: JourneyStopEntity

    func destination(for language: TransitLanguage) -> String {
        journey.destinationStop?.displayName(for: language)
            ?? route.displayDestination(for: language)
    }
}
