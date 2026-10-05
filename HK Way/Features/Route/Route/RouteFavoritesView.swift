//
//  RouteFavoritesView.swift
//  HK Way
//
//  Created by Ken on 22/8/2026.
//

import SwiftUI
import SwiftData
import CoreLocation

struct RouteFavoritesView: View {

    let isFavoritesActive: Bool
    let onMenuTap: () -> Void

    init(
        isFavoritesActive: Bool = true,
        onMenuTap: @escaping () -> Void = {}
    ) {
        self.isFavoritesActive = isFavoritesActive
        self.onMenuTap = onMenuTap
    }

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.modelContext)
    private var modelContext

    @AppStorage("favoriteRouteIds")
    private var favoriteRouteIdsValue = ""

    @AppStorage("favoriteStopIds")
    private var favoriteStopIdsValue = ""

    @State
    private var selection: FavoriteType = .routes

    @State
    private var favoriteStops: [StopEntity] = []

    @State
    private var favoriteRoutes: [FavoriteRouteEntry] = []

    @State
    private var selectedFavoriteRouteID: String?

    @State
    private var selectedFavoriteStopID: String?

    @State
    private var selectedJourneyStopID: String?

    @State
    private var etaResults: [String: RouteETAResult] = [:]

    @State
    private var loadingRouteIds: Set<String> = []

    @State
    private var preparedWidgetRouteIds: Set<String> = []

    @Environment(AppLocationManager.self)
    private var locationManager

    private var favoriteRouteIds: Set<String> {
        storedIds(from: favoriteRouteIdsValue)
    }

    private var favoriteStopIds: Set<String> {
        storedIds(from: favoriteStopIdsValue)
    }

    private var navigationTitle: String {
        switch transitLanguage {
        case .english:
            "Favorites"
        case .traditionalChinese, .simplifiedChinese:
            "收藏"
        }
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                NavigationSplitView {
                    favoritesBrowser
                        .navigationSplitViewColumnWidth(
                            min: 320,
                            ideal: 380,
                            max: 440
                        )
                } detail: {
                    favoriteDetail
                }
            } else {
                favoritesBrowser
            }
        }
        .navigationTitle(
            navigationTitle
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("Menu")
            }
        }
        .task(id: favoriteStopIdsValue) {
            loadFavoriteStops()
        }
        .task(id: favoriteRouteIdsValue) {
            loadFavoriteRoutes()

            if isFavoritesActive {
                locationManager.requestLocation()
            }
        }
        .onChange(of: isFavoritesActive) {
            _, isActive in

            if isActive {
                locationManager.requestLocation()
            }
        }
        .onChange(of: selection) {
            selectedFavoriteRouteID = nil
            selectedFavoriteStopID = nil
            selectedJourneyStopID = nil
        }
    }

    private var favoritesBrowser: some View {
        ZStack {
            CustomAppBackgroundView()

            VStack(spacing: 0) {
                ActiveJourneyCard()

                Picker(
                    "Favorite Type",
                    selection: $selection
                ) {
                    ForEach(FavoriteType.allCases) { type in
                        Text(type.title(for: transitLanguage))
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                switch selection {
                case .routes:
                    favoriteRoutesContent
                case .stops:
                    favoriteStopsContent
                case .mtr:
                    MTRFavoritesView()
                case .lightRail:
                    LightRailFavoritesView()
                }
            }
        }
    }

    @ViewBuilder
    private var favoriteDetail: some View {
        ZStack {
            CustomAppBackgroundView()

            if selection == .routes,
               let favorite = favoriteRoutes.first(
                where: { $0.id == selectedFavoriteRouteID }
               ) {
                if let journey = favorite.journey {
                    if let journeyStop = journey.journeyStops.first(
                        where: { $0.id == selectedJourneyStopID }
                    ), let stop = journeyStop.stop {
                        StopDetailView(
                            stop: stop,
                            journey: journey,
                            journeyStop: journeyStop
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    selectedJourneyStopID = nil
                                } label: {
                                    Label("Back to Route", systemImage: "chevron.left")
                                }
                            }
                        }
                    } else {
                        DeferredJourneyStopListView(
                            journey: journey,
                            onSelectStop: { journeyStop in
                                selectedJourneyStopID = journeyStop.id
                            }
                        )
                    }
                } else {
                    RouteDetailView(route: favorite.route)
                }
            } else if selection == .stops,
                      let stop = favoriteStops.first(
                        where: { $0.id == selectedFavoriteStopID }
                      ) {
                FavoriteStopDetailView(stop: stop)
            } else {
                ContentUnavailableView(
                    detailSelectionTitle,
                    systemImage: "bookmark.fill",
                    description: Text(detailSelectionDescription)
                )
            }
        }
    }

    @ViewBuilder
    private var favoriteRoutesContent: some View {
        if favoriteRoutes.isEmpty {
            CustomCardView(
                imageIcon: "bookmark",
                title: "No Favorite Routes",
                subTitle: "Routes you save will appear here.",
                animated: false
            )
        } else {
            List(favoriteRoutes) { favorite in
                Group {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Button {
                            selectedFavoriteRouteID = favorite.id
                            selectedJourneyStopID = nil
                        } label: {
                            favoriteRouteRow(favorite)
                        }
                    } else {
                        NavigationLink {
                            if let journey = favorite.journey {
                                DeferredJourneyStopListView(journey: journey)
                            } else {
                                RouteDetailView(route: favorite.route)
                            }
                        } label: {
                            favoriteRouteRow(favorite)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        removeRoute(favorite.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var favoriteStopsContent: some View {
        if favoriteStops.isEmpty {
            CustomCardView(
                imageIcon: "mappin.and.ellipse",
                title: "No Favorite Stops",
                subTitle: "Stops you save will appear here.",
                animated: false
            )
        } else {
            List(favoriteStops) { stop in
                Group {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Button {
                            selectedFavoriteStopID = stop.id
                        } label: {
                            favoriteStopRow(stop)
                        }
                    } else {
                        NavigationLink {
                            FavoriteStopDetailView(stop: stop)
                        } label: {
                            favoriteStopRow(stop)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        removeStop(stop.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func favoriteRouteRow(_ favorite: FavoriteRouteEntry) -> some View {
        RouteRowView(
            route: favorite.route,
            origin: favorite.origin(for: transitLanguage),
            destination: favorite.destination(for: transitLanguage),
            etaResult: etaResults[favorite.id],
            isCompact: true,
            showsDirectionIndicator: true
        )
        .environment(\.locale, transitLanguage.locale)
        .task(id: etaTaskID(for: favorite)) {
            guard isFavoritesActive,
                  let userLocation = locationManager.location else {
                return
            }

            while !Task.isCancelled {
                await loadETA(
                    for: favorite,
                    userLocation: userLocation,
                    forceRefresh: etaResults[favorite.id] != nil
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
    }

    private func favoriteStopRow(_ stop: StopEntity) -> some View {
        Label {
            Text(
                stop.displayName(
                    for: transitLanguage
                )
            )
        } icon: {
            Image(systemName: "mappin.and.ellipse")
        }
    }

    private var detailSelectionTitle: String {
        switch transitLanguage {
        case .english: "Select a Favorite"
        case .traditionalChinese: "選擇收藏項目"
        case .simplifiedChinese: "选择收藏项目"
        }
    }

    private var detailSelectionDescription: String {
        switch transitLanguage {
        case .english: "Choose a saved route or stop from the sidebar."
        case .traditionalChinese: "從側邊欄選擇已收藏的路線或車站。"
        case .simplifiedChinese: "从侧边栏选择已收藏的路线或车站。"
        }
    }

    private func storedIds(from value: String) -> Set<String> {
        Set(
            value.split(separator: "\n")
                .map(String.init)
        )
    }

    private func removeRoute(_ id: String) {
        var ids = favoriteRouteIds
        ids.remove(id)
        favoriteRouteIdsValue = ids.sorted()
            .joined(separator: "\n")
        TransitWidgetSnapshotStore.removeRoute(id)
    }

    private func removeStop(_ id: String) {
        var ids = favoriteStopIds
        ids.remove(id)
        favoriteStopIdsValue = ids.sorted()
            .joined(separator: "\n")
    }

    private func etaTaskID(for favorite: FavoriteRouteEntry) -> String {
        let timestamp = locationManager.location?
            .timestamp.timeIntervalSince1970 ?? 0

        return "\(favorite.id)|\(timestamp)|\(isFavoritesActive)"
    }

    @MainActor
    private func loadFavoriteRoutes() {
        favoriteRoutes = favoriteRouteIds.compactMap { storedID in
            let components = storedID.split(separator: "|", maxSplits: 1)
            let routeID = String(components[0])
            let direction = components.count == 2 ? String(components[1]) : nil
            var descriptor = FetchDescriptor<RouteEntity>(
                predicate: #Predicate {
                    $0.id == routeID
                }
            )
            descriptor.fetchLimit = 1

            guard let route = try? modelContext.fetch(descriptor).first else {
                return nil
            }

            let journey = direction.flatMap { savedDirection in
                route.journeys
                    .filter { $0.direction == savedDirection }
                    .max { $0.journeyStops.count < $1.journeyStops.count }
            }
            return FavoriteRouteEntry(
                id: storedID,
                route: route,
                journey: journey
            )
        }
        .sorted {
            $0.route.number.localizedStandardCompare($1.route.number)
                == .orderedAscending
        }

        let loadedIds = Set(favoriteRoutes.map(\.id))
        etaResults = etaResults.filter {
            loadedIds.contains($0.key)
        }
        loadingRouteIds.formIntersection(loadedIds)
    }

    @MainActor
    private func loadFavoriteStops() {
        favoriteStops = favoriteStopIds.compactMap { id in
            let favoriteId = id
            var descriptor = FetchDescriptor<StopEntity>(
                predicate: #Predicate {
                    $0.id == favoriteId
                }
            )
            descriptor.fetchLimit = 1

            return try? modelContext.fetch(descriptor).first
        }
        .compactMap { $0 }
        .sorted {
            $0.displayName(for: transitLanguage)
                .localizedStandardCompare(
                    $1.displayName(for: transitLanguage)
                ) == .orderedAscending
        }
    }

    @MainActor
    private func loadETA(
        for favorite: FavoriteRouteEntry,
        userLocation: CLLocation,
        forceRefresh: Bool
    ) async {
        let favoriteID = favorite.id
        let route = favorite.route

        guard
            forceRefresh || etaResults[favoriteID] == nil,
            !loadingRouteIds.contains(favoriteID)
        else {
            return
        }

        loadingRouteIds.insert(favoriteID)

        let coordinator = ETARefreshCoordinator.shared
        await coordinator.acquire()

        guard !Task.isCancelled else {
            loadingRouteIds.remove(favoriteID)
            await coordinator.release()
            return
        }

        do {
            let result = try await RouteETAResolver().resolve(
                route: route,
                userLocation: userLocation,
                modelContext: modelContext
            )

            if !Task.isCancelled, let result {
                etaResults[favoriteID] = result

                if !preparedWidgetRouteIds.contains(route.id) {
                    preparedWidgetRouteIds.insert(route.id)
                    await prepareWidgetSnapshots(
                        for: route,
                        userLocation: userLocation
                    )
                } else {
                    TransitWidgetSnapshotStore.save(
                        TransitWidgetSnapshot(
                            route: route,
                            result: result
                        )
                    )
                }
            }
        } catch {}

        loadingRouteIds.remove(favoriteID)
        await coordinator.release()
    }

    @MainActor
    private func prepareWidgetSnapshots(
        for route: RouteEntity,
        userLocation: CLLocation
    ) async {
        var journeysByDirection: [String: JourneyEntity] = [:]

        for journey in route.journeys {
            let destinationId = journey.destinationStop?.id ?? "unknown"
            let key = "\(journey.direction)|\(destinationId)"

            if let existing = journeysByDirection[key],
               existing.journeyStops.count >= journey.journeyStops.count {
                continue
            }

            journeysByDirection[key] = journey
        }

        var snapshots: [TransitWidgetSnapshot] = []

        for journey in journeysByDirection.values {
            guard !Task.isCancelled else {
                return
            }

            for journeyStop in journey.journeyStops.sorted(
                by: { $0.sequence < $1.sequence }
            ) {
                guard !Task.isCancelled else {
                    return
                }

                let journeyId = journey.id
                guard let stopId = journeyStop.stop?.id else {
                    continue
                }
                let sequence = journeyStop.sequence
                let descriptor = FetchDescriptor<OperatorStopReferenceEntity>(
                    predicate: #Predicate {
                        $0.journeyId == journeyId
                            && $0.stopId == stopId
                            && $0.sequence == sequence
                    }
                )
                guard
                    journeyStop.stop != nil,
                    let references = try? modelContext.fetch(descriptor),
                    !references.isEmpty
                else {
                    continue
                }

                snapshots.append(
                    TransitWidgetSnapshot(
                        route: route,
                        journey: journey,
                        journeyStop: journeyStop,
                        references: references
                    )
                )
            }
        }

        guard !snapshots.isEmpty else {
            return
        }

        TransitWidgetSnapshotStore.replaceRouteSnapshots(
            snapshots,
            routeId: route.id
        )
    }
}

private struct FavoriteRouteEntry: Identifiable {
    let id: String
    let route: RouteEntity
    let journey: JourneyEntity?

    func origin(for language: TransitLanguage) -> String? {
        orderedStops.first?.stop?.displayName(for: language)
    }

    func destination(for language: TransitLanguage) -> String? {
        orderedStops.last?.stop?.displayName(for: language)
    }

    private var orderedStops: [JourneyStopEntity] {
        journey?.journeyStops.sorted { $0.sequence < $1.sequence } ?? []
    }
}

private enum FavoriteType: CaseIterable, Identifiable {
    case routes
    case stops
    case mtr
    case lightRail

    var id: Self { self }

    func title(for language: TransitLanguage) -> String {
        switch (self, language) {
        case (.routes, .english): "Routes"
        case (.routes, .traditionalChinese): "路線"
        case (.routes, .simplifiedChinese): "路线"
        case (.stops, .english): "Stops"
        case (.stops, .traditionalChinese): "車站"
        case (.stops, .simplifiedChinese): "车站"
        case (.mtr, .english): "MTR"
        case (.mtr, .traditionalChinese): "港鐵"
        case (.mtr, .simplifiedChinese): "港铁"
        case (.lightRail, .english): "Light Rail"
        case (.lightRail, .traditionalChinese): "輕鐵"
        case (.lightRail, .simplifiedChinese): "轻铁"
        }
    }
}

#Preview {
    NavigationStack {
        RouteFavoritesView()
    }
    .environment(AppLocationManager())
}
