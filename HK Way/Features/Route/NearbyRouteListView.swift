//
//  NearbyRouteListView.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import SwiftUI
import SwiftData
import CoreLocation

struct NearbyRouteListView: View {

    let isNearbyTabSelected: Bool
    let onMenuTap: () -> Void

    init(
        isNearbyTabSelected: Bool = true,
        onMenuTap: @escaping () -> Void = {}
    ) {
        self.isNearbyTabSelected = isNearbyTabSelected
        self.onMenuTap = onMenuTap
    }

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.transitLanguage)
    private var transitLanguage
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @Query
    private var operatorStopReferences:
        [OperatorStopReferenceEntity]

    @Environment(AppLocationManager.self)
    private var locationManager

    @State
    private var nearbyMatches:
        [NearbyRouteMatch] = []

    @State
    private var etaResults:
        [String: RouteETAResult] = [:]

    @State
    private var loadingRouteIds:
        Set<String> = []

    @State
    private var unavailableETAIds:
        Set<String> = []

    @State
    private var failedETAIds:
        Set<String> = []

    @State
    private var collapsedStopGroupIDs: Set<String> = []

    @State private var nearbyLoadState = NearbyLoadState()
    private var isLoadingNearbyRoutes: Bool { nearbyLoadState.isLoading }

    @State
    private var nearbyRefreshID = 0

    @State
    private var nearbyRouteIndex: NearbyRouteIndex?

    @State
    private var nearbyMatchesByJourneyStopId:
        [String: NearbyRouteMatch] = [:]

    @State
    private var selectedNearbyMatchID: String?

    @State
    private var selectedNearbyJourneyStopID: String?

    @State
    private var nearbyLoadTask: Task<Void, Never>?

    @AppStorage(OperatorSelectionPreference.storageKey)
    private var selectedOperatorIdsValue = ""

    @State
    private var operatorFilter: NearbyOperatorFilter = .preferences
    @AppStorage(NearbySearchRadius.storageKey) private var storedRadius = 100
    @AppStorage("nearbyRoutePresentation")
    private var nearbyRoutePresentation = "grouped"
    private var searchRadius: NearbySearchRadius { NearbySearchRadius(storedValue: storedRadius) }

    private var settingsOperatorIds: Set<String> {
        OperatorSelectionPreference.ids(
            from: selectedOperatorIdsValue
        )
    }

    private var isLocationAccessDenied: Bool {
        let status =
            locationManager.authorizationStatus

        return status == .denied ||
            status == .restricted
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                NavigationSplitView {
                    nearbyScreen
                        .navigationSplitViewColumnWidth(
                            min: 340,
                            ideal: 400,
                            max: 460
                        )
                } detail: {
                    nearbyDetail
                }
            } else {
                nearbyScreen
            }
        }
    }

    private var nearbyScreen: some View {

        NavigationStack {
            ZStack {
                CustomAppBackgroundView()

                Group {

                if isLocationAccessDenied {

                    CustomCardView(
                        imageIcon: "location.slash",
                        title: "Location Access Required",
                        subTitle: "Allow location access in Settings to find nearby routes.",
                        animated: false
                    )

                } else if isLoadingNearbyRoutes {

                    CustomCardView(
                        imageIcon: "location.fill",
                        title: "Finding nearby routes...",
                        subTitle: "HK Way is checking routes near your current location.",
                        animated: true
                    )

                } else if locationManager.location == nil && locationManager.error != nil {
                    CustomCardView(
                        imageIcon: "location.slash",
                        title: "Unable to Find Your Location",
                        subTitle: "Tap refresh to try your location again.",
                        animated: false
                    )
                } else if locationManager.location == nil {

                    CustomCardView(
                        imageIcon: "location",
                        title: "Finding your location",
                        subTitle: "HK Way uses your location to find nearby routes and arrival times.",
                        animated: true
                    )

                } else if nearbyMatches.isEmpty && nearbyRailStations.isEmpty {

                    CustomCardView(
                        imageIcon: "bus.fill",
                        title: "No Nearby Routes",
                        subTitle: "No routes within this radius. Try a wider search distance.",
                        animated: false
                    )

                } else if filteredNearbyMatches.isEmpty && nearbyRailStations.isEmpty {
                    CustomCardView(
                        imageIcon: "line.3.horizontal.decrease.circle",
                        title: "Nearby Routes Hidden by Filters",
                        subTitle: "Check the operator filter and your operator preferences in Settings.",
                        animated: false
                    )
                } else {

                    nearbyList
                }
                }
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    ActiveJourneyCard()
                    Text("Search Radius").font(.caption).foregroundStyle(.secondary)
                    Picker("Search Radius", selection: Binding(
                        get: { searchRadius }, set: { storedRadius = $0.rawValue }
                    )) {
                        ForEach(NearbySearchRadius.allCases) { radius in
                            Text(LocalizedStringKey(radius.title)).tag(radius)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(.primary)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.bar)
            }
            .toolbar {

                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onMenuTap) {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Menu")
                }

                ToolbarItem(
                    placement: .topBarLeading
                ) {

                    operatorFilterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    nearbyPresentationMenu
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { refreshNearbyRoutes(force: true) } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh Nearby Routes")
                    .disabled(isLoadingNearbyRoutes)
                }

            }
        }
        .task {
            guard isNearbyTabSelected else {
                return
            }

            locationManager.requestLocation()

            if let cachedLocation =
                locationManager.location {
                loadNearbyRoutes(
                    userLocation: cachedLocation
                )
            }
        }
        .onChange(
            of: locationManager.location
        ) { _, newLocation in

            guard
                isNearbyTabSelected,
                let location =
                newLocation
            else {
                return
            }

            loadNearbyRoutes(
                userLocation: location
            )

        }
            .onChange(
            of: routes.count
        ) { _, _ in

            invalidateNearbyRouteIndex()

            guard let location =
                locationManager.location
            else {
                return
            }

            loadNearbyRoutes(
                userLocation: location,
                force: true
            )
        }
        .onChange(
            of: operatorStopReferences.count
        ) { _, _ in

            invalidateNearbyRouteIndex()

            guard let location =
                locationManager.location
            else {
                return
            }

            loadNearbyRoutes(
                userLocation: location,
                force: true
            )
        }
        .onChange(of: isNearbyTabSelected) {
            _, isSelected in

            if isSelected {
                refreshNearbyRoutes(force: true)
            } else {
                cancelNearbyLoad()
            }
        }
        .onChange(of: searchRadius) { _, _ in
            guard isNearbyTabSelected, scenePhase == .active else { return }
            if let location = locationManager.location {
                loadNearbyRoutes(userLocation: location, force: true)
            } else {
                locationManager.requestLocation()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isNearbyTabSelected {
                refreshNearbyRoutes(force: true)
            } else if phase != .active {
                cancelNearbyLoad()
            }
        }
        .onDisappear { cancelNearbyLoad() }
    }

    @ViewBuilder
    private var nearbyDetail: some View {
        ZStack {
            CustomAppBackgroundView()

            if let match = filteredNearbyMatches.first(
                where: { $0.journeyStop.id == selectedNearbyMatchID }
            ) {
                NavigationStack {
                    if let journeyStop = match.journey.journeyStops.first(
                        where: { $0.id == selectedNearbyJourneyStopID }
                    ), let stop = journeyStop.stop {
                        StopDetailView(
                            stop: stop,
                            journey: match.journey,
                            journeyStop: journeyStop
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    selectedNearbyJourneyStopID = nil
                                } label: {
                                    Label("Back to Route", systemImage: "chevron.left")
                                }
                            }
                        }
                    } else {
                        DeferredJourneyStopListView(
                            journey: match.journey,
                            highlightsNearestETAOnAppear: true,
                            onSelectStop: { journeyStop in
                                selectedNearbyJourneyStopID = journeyStop.id
                            }
                        )
                    }
                }
            } else {
                ContentUnavailableView(
                    nearbySelectionTitle,
                    systemImage: "location.fill",
                    description: Text(nearbySelectionDescription)
                )
            }
        }
    }

    private var nearbySelectionTitle: String {
        switch transitLanguage {
        case .english: "Select a Nearby Route"
        case .traditionalChinese: "選擇附近路線"
        case .simplifiedChinese: "选择附近路线"
        }
    }

    private var nearbySelectionDescription: String {
        switch transitLanguage {
        case .english: "Choose a route from the nearby stops list."
        case .traditionalChinese: "從附近車站列表選擇路線。"
        case .simplifiedChinese: "从附近车站列表选择路线。"
        }
    }

    // MARK: - Sort by Distance, then Route

    private var sortedNearbyMatches:
        [NearbyRouteMatch] {

        nearbyMatches.sorted { lhs, rhs in

            if lhs.distanceMeters !=
                rhs.distanceMeters {

                return lhs.distanceMeters <
                    rhs.distanceMeters
            }

            let routeComparison =
                lhs.route.number
                    .localizedStandardCompare(
                        rhs.route.number
                    )

            if routeComparison != .orderedSame {
                return routeComparison ==
                    .orderedAscending
            }

            return lhs.route.id <
                rhs.route.id
        }
    }

    // MARK: - Operator Filter

    private var filteredNearbyMatches:
        [NearbyRouteMatch] {

        return sortedNearbyMatches.filter {
            match in

            operatorFilter.includes(operatorIds(for: match.route), preferences: settingsOperatorIds)
        }
    }

    private var allOperatorIds:
        [String] {

        Array(
            Set(
                nearbyMatches.flatMap {
                    operatorIds(
                        for: $0.route
                    )
                }
            )
        )
        .sorted()
    }

    private var isGroupedRoutePresentation: Bool {
        nearbyRoutePresentation != "list"
    }

    private var nearbyPresentationMenu: some View {
        Menu {
            Button { nearbyRoutePresentation = "grouped" } label: {
                if isGroupedRoutePresentation {
                    Label(groupedPresentationTitle, systemImage: "checkmark")
                } else {
                    Text(groupedPresentationTitle)
                }
            }

            Button { nearbyRoutePresentation = "list" } label: {
                if !isGroupedRoutePresentation {
                    Label(allRoutesPresentationTitle, systemImage: "checkmark")
                } else {
                    Text(allRoutesPresentationTitle)
                }
            }
        } label: {
            Image(systemName: isGroupedRoutePresentation ? "rectangle.3.group" : "list.bullet")
        }
        .accessibilityLabel(routeDisplayAccessibilityLabel)
    }

    private var groupedPresentationTitle: String {
        transitLanguage.newsText("Group by Boarding Stop", "按上車站分組", "按上车站分组")
    }

    private var allRoutesPresentationTitle: String {
        transitLanguage.newsText("All Routes", "所有路線", "所有路线")
    }

    private var routeDisplayAccessibilityLabel: String {
        transitLanguage.newsText("Route display", "路線顯示方式", "路线显示方式")
    }

    private var allNearbyRoutesSummary: String {
        transitLanguage.newsText("All nearby routes · \(filteredNearbyMatches.count) routes", "附近所有路線 · \(filteredNearbyMatches.count) 條", "附近所有路线 · \(filteredNearbyMatches.count) 条")
    }

    private var operatorFilterMenu:
        some View {

        Menu {

            Button {
                operatorFilter = .all
            } label: {

                if operatorFilter == .all {
                    Label(
                        "All Operators",
                        systemImage: "checkmark"
                    )
                } else {
                    Text("All Operators")
                }
            }

            Divider()

            Button { operatorFilter = .preferences } label: {
                if operatorFilter == .preferences {
                    Label("Use Settings Preferences", systemImage: "checkmark")
                } else {
                    Text("Use Settings Preferences")
                }
            }

            Divider()

            ForEach(
                allOperatorIds,
                id: \.self
            ) { operatorId in

                Button {
                    toggleOperator(operatorId)
                } label: {

                    if operatorFilter.isSelected(operatorId) {

                        Label(
                            CustomBadgeView.displayText(
                                for: operatorId,
                                language: transitLanguage
                            ),
                            systemImage: "checkmark"
                        )

                    } else {
                        Text(
                            CustomBadgeView.displayText(
                                for: operatorId,
                                language: transitLanguage
                            )
                        )
                    }
                }
            }

        } label: {

            Image(
                systemName:
                    operatorFilter == .all || (operatorFilter == .preferences && settingsOperatorIds.isEmpty)
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityLabel(
            "Filter by operator"
        )
        .foregroundStyle(.primary)
        .tint(.primary)
    }

    private func operatorIds(
        for route: RouteEntity
    ) -> Set<String> {

        Set(
            route.operators.flatMap {
                $0.id.split(separator: "+")
                    .map(String.init)
            }
        )
    }

    private func toggleOperator(_ operatorId: String) {
        operatorFilter.toggle(operatorId)
    }

    private var nearbyRailStations: [NearbyRailStationMatch] {
        guard let location = locationManager.location else { return [] }
        return NearbyRailStationIndex.nearby(to: location, within: 400)
    }

    private func nearbyRailStationRow(_ station: NearbyRailStationMatch) -> some View {
        HStack(spacing: 12) {
            Image(systemName: station.kind == .mtr ? "tram.fill" : "lightrail.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(station.displayName(for: transitLanguage))
                    .font(.headline)
                Text(station.kind.label(for: transitLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(distanceText(station.distanceMeters))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Nearby List

    private var nearbyList: some View {

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        isGroupedRoutePresentation ? stopAreaSummary : allNearbyRoutesSummary,
                        systemImage: isGroupedRoutePresentation
                            ? (combinedStopCount > 1
                                ? "point.3.connected.trianglepath.dotted"
                                : "mappin.and.ellipse")
                            : "list.bullet"
                    )
                    .font(.subheadline.weight(.semibold))

                    if isGroupedRoutePresentation && combinedStopCount > 1 {
                        Text(
                            transitLanguage.newsText("Routes are grouped by their physical boarding stop. Check the stop name and code before boarding.", "路線按實際上車站分組。上車前請核對車站名稱及編號。", "路线按实际上车站分组。上车前请核对车站名称及编号。")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .listRowSeparator(.hidden)

            if !nearbyRailStations.isEmpty {
                Section {
                    ForEach(nearbyRailStations) { station in
                        Group {
                            if station.kind == .mtr {
                                NavigationLink {
                                    MTRStationQuickOpenView(stationEnglish: station.station.english)
                                } label: {
                                    nearbyRailStationRow(station)
                                }
                            } else {
                                NavigationLink {
                                    NearbyLightRailStationView(stationEnglish: station.station.english)
                                } label: {
                                    nearbyRailStationRow(station)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Label(
                        transitLanguage.newsText("Nearby Rail Stations", "附近港鐵及輕鐵站", "附近地铁及轻铁站"),
                        systemImage: "tram.fill"
                    )
                }
                .headerProminence(.increased)
            }

            if isGroupedRoutePresentation {
                ForEach(nearbyStopGroups) { group in
                Section {
                    if !collapsedStopGroupIDs.contains(group.id) {
                        ForEach(
                            group.matches,
                            id: \.journeyStop.id
                        ) { match in

                            Group {
                                if UIDevice.current.userInterfaceIdiom == .pad {
                                    Button {
                                        selectedNearbyMatchID = match.journeyStop.id
                                        selectedNearbyJourneyStopID = nil
                                    } label: {
                                        nearbyRouteRow(match)
                                    }
                                } else {
                                    NavigationLink {
                                        RouteDetailView(route: match.route)
                                    } label: {
                                        nearbyRouteRow(match)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .task(
                                id: "\(nearbyRefreshID)|\(isNearbyTabSelected)"
                            ) {
                                    guard isNearbyTabSelected else {
                                        return
                                    }

                                    guard let userLocation =
                                        locationManager.location
                                    else {
                                        return
                                    }

                                    while !Task.isCancelled {
                                        await loadETA(
                                            for: match,
                                            userLocation: userLocation,
                                            forceRefresh:
                                                etaResults[
                                                    match.journeyStop.id
                                                ] != nil
                                        )

                                        do {
                                            try await Task.sleep(
                                                for: ETARefreshCoordinator
                                                    .refreshInterval
                                            )
                                        } catch {
                                            return
                                        }
                                    }
                            }
                        }
                    }
                } header: {
                    stopGroupHeader(group)
                }
                .headerProminence(.standard)
                }
            }

            if !isGroupedRoutePresentation {
                Section {
                    ForEach(filteredNearbyMatches, id: \.journeyStop.id) { match in
                        nearbyRouteNavigationRow(match)
                            .buttonStyle(.plain)
                            .task(id: "\(nearbyRefreshID)|\(isNearbyTabSelected)") {
                                await refreshETAWhileVisible(for: match)
                            }
                    }
                } header: {
                    Label(allNearbyRoutesSummary, systemImage: "list.bullet")
                }
                .headerProminence(.standard)
            }
        }
        .listSectionSpacing(.compact)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            refreshNearbyRoutes(force: true)
        }
    }

    @ViewBuilder
    private func nearbyRouteNavigationRow(_ match: NearbyRouteMatch) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            Button {
                selectedNearbyMatchID = match.journeyStop.id
                selectedNearbyJourneyStopID = nil
            } label: {
                nearbyRouteRow(match)
            }
        } else {
            NavigationLink {
                RouteDetailView(route: match.route)
            } label: {
                nearbyRouteRow(match)
            }
        }
    }

    private func refreshETAWhileVisible(for match: NearbyRouteMatch) async {
        guard isNearbyTabSelected, let userLocation = locationManager.location else { return }

        while !Task.isCancelled {
            await loadETA(
                for: match,
                userLocation: userLocation,
                forceRefresh: etaResults[match.journeyStop.id] != nil
            )

            do {
                try await Task.sleep(for: ETARefreshCoordinator.refreshInterval)
            } catch {
                return
            }
        }
    }

    private func nearbyRouteRow(_ match: NearbyRouteMatch) -> some View {
        RouteRowView(
            route: match.route,
            destination: match.journey.destinationStop?
                .displayName(for: transitLanguage),
            etaResult: etaResults[match.journeyStop.id],
            isLoadingETA: loadingRouteIds.contains(match.journeyStop.id),
            isETAUnavailable: unavailableETAIds.contains(match.journeyStop.id),
            didETAFail: failedETAIds.contains(match.journeyStop.id)
        )
    }

    private var nearbyStopGroups: [NearbyStopGroup] {
        Dictionary(grouping: filteredNearbyMatches, by: \.stop.id)
            .map { stopId, matches in
                NearbyStopGroup(
                    id: stopId,
                    stop: matches[0].stop,
                    matches: matches,
                    distanceMeters: matches
                        .map(\.distanceMeters)
                        .min() ?? 0,
                    stopCodes: Array(
                        Set(
                            matches.compactMap {
                                $0.journeyStop.publicStopCode
                            }
                        )
                    )
                    .sorted()
                )
            }
            .sorted { lhs, rhs in
                lhs.distanceMeters < rhs.distanceMeters
            }
    }

    private func stopGroupHeader(
        _ group: NearbyStopGroup
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedStopGroupIDs.contains(group.id) {
                    collapsedStopGroupIDs.remove(group.id)
                } else {
                    collapsedStopGroupIDs.insert(group.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(
                        systemName: collapsedStopGroupIDs.contains(group.id)
                            ? "chevron.right"
                            : "chevron.down"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                    Text(group.stop.displayName(for: transitLanguage))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(distanceText(group.distanceMeters))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if !group.stopCodes.isEmpty {
                        Text(group.stopCodes.joined(separator: " · "))
                    }

                    if !group.stopCodes.isEmpty {
                        Text(verbatim: "·")
                    }

                    Text(routeCountText(group.matches.count))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if collapsedStopGroupIDs.contains(group.id),
                   let destinationSummary = destinationSummary(for: group) {
                    Text(destinationSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .padding(.vertical, 2)
    }

    private func destinationSummary(
        for group: NearbyStopGroup
    ) -> String? {
        var seen = Set<String>()
        let destinations = group.matches.compactMap { match -> String? in
            guard let destination = match.journey.destinationStop?
                .displayName(for: transitLanguage),
                  !destination.isEmpty,
                  seen.insert(destination).inserted
            else {
                return nil
            }
            return destination
        }

        guard !destinations.isEmpty else { return nil }

        let shown = destinations.prefix(2).joined(separator: ", ")
        let remaining = destinations.count - min(destinations.count, 2)

        switch transitLanguage {
        case .english:
            return remaining == 0
                ? "Towards \(shown)"
                : "Towards \(shown) + \(remaining) more"
        case .traditionalChinese:
            return remaining == 0
                ? "往 \(shown)"
                : "往 \(shown)及其他 \(remaining) 個方向"
        case .simplifiedChinese:
            return remaining == 0
                ? "往 \(shown)"
                : "往 \(shown)及其他 \(remaining) 个方向"
        }
    }

    private var combinedStopCount: Int {
        Set(
            filteredNearbyMatches.map(\.stop.id)
        ).count
    }

    private var stopAreaSummary: String {
        guard combinedStopCount > 1 else {
            switch transitLanguage {
            case .english:
                return "Nearest boarding stop"
            case .traditionalChinese:
                return "最近的上車站"
            case .simplifiedChinese:
                return "最近的上车站"
            }
        }

        switch transitLanguage {
        case .english:
                return "Nearby boarding points · \(combinedStopCount) stops"
        case .traditionalChinese:
                return "附近上車站 · \(combinedStopCount) 個車站"
        case .simplifiedChinese:
                return "附近上车站 · \(combinedStopCount) 个车站"
        }
    }

    private func routeCountText(_ count: Int) -> String {
        switch transitLanguage {
        case .english:
            return count == 1 ? "1 route" : "\(count) routes"
        case .traditionalChinese:
            return "\(count) 條路線"
        case .simplifiedChinese:
            return "\(count) 条路线"
        }
    }

    private func distanceText(
        _ distance: CLLocationDistance
    ) -> String {
        let meters = Int(distance.rounded())

        switch transitLanguage {
        case .english:
            return "\(meters) m away"
        case .traditionalChinese:
            return "距離 \(meters) 米"
        case .simplifiedChinese:
            return "距离 \(meters) 米"
        }
    }

    // MARK: - Load Nearby Routes

    private func loadNearbyRoutes(
        userLocation: CLLocation,
        force: Bool = false
    ) {
        guard isNearbyTabSelected, scenePhase == .active else { return }
        guard !routes.isEmpty else {
            cancelNearbyLoad()
            nearbyMatches = []
            etaResults = [:]
            return
        }
        guard nearbyLoadState.shouldLoad(location: userLocation,
            indexReady: nearbyRouteIndex != nil, hasMatches: !nearbyMatches.isEmpty, force: force) else { return }

        nearbyLoadTask?.cancel()
        let requestID = nearbyLoadState.begin()
        let latitude = userLocation.coordinate.latitude
        let longitude = userLocation.coordinate.longitude
        let radiusMeters = Double(searchRadius.rawValue)

        nearbyLoadTask = Task {
            defer { nearbyLoadState.finish(requestID) }
            await prepareNearbyRouteIndex(requestID: requestID)

            guard
                !Task.isCancelled,
                requestID == nearbyLoadState.requestID,
                let nearbyRouteIndex
            else {
                return
            }

            let candidateResults = await Task.detached(
                priority: .userInitiated
            ) {
                nearbyRouteIndex.nearbyJourneyStops(
                    latitude: latitude,
                    longitude: longitude,
                    maximumDistanceMeters: radiusMeters
                )
            }
            .value

            guard
                !Task.isCancelled,
                requestID == nearbyLoadState.requestID
            else {
                return
            }

            nearbyMatches = candidateResults.compactMap { result in
                guard let match =
                    nearbyMatchesByJourneyStopId[
                        result.journeyStopId
                    ]
                else {
                    return nil
                }

                return NearbyRouteMatch(
                    route: match.route,
                    journey: match.journey,
                    journeyStop: match.journeyStop,
                    stop: match.stop,
                    distanceMeters: result.distanceMeters
                )
            }

            nearbyLoadState.finish(requestID, location: userLocation)
            etaResults = [:]
            loadingRouteIds = []
            unavailableETAIds = []
            failedETAIds = []
            nearbyRefreshID += 1
        }

    }

    private func prepareNearbyRouteIndex(requestID: Int) async {
        guard nearbyRouteIndex == nil else {
            return
        }

        let preparation = await NearbyRouteIndex.prepare(
            routes: routes,
            operatorStopReferences: operatorStopReferences
        )

        guard !Task.isCancelled, requestID == nearbyLoadState.requestID else {
            return
        }

        nearbyRouteIndex = preparation.index
        nearbyMatchesByJourneyStopId =
            preparation.matchesByJourneyStopId
    }

    private func invalidateNearbyRouteIndex() {
        cancelNearbyLoad()
        nearbyLoadState.cancel(invalidateLocation: true)
        nearbyRouteIndex = nil
        nearbyMatchesByJourneyStopId = [:]
    }

    private func cancelNearbyLoad() {
        nearbyLoadTask?.cancel()
        nearbyLoadTask = nil
        nearbyLoadState.cancel()
    }

    @MainActor
    private func refreshNearbyRoutes(force: Bool = false) {
        if let location = locationManager.location {
            loadNearbyRoutes(
                userLocation: location,
                force: force
            )
        }

        locationManager.requestLocation(force: force)
    }

    // MARK: - Route ETA

    @MainActor
    private func loadETA(
        for match: NearbyRouteMatch,
        userLocation: CLLocation,
        forceRefresh: Bool = false
    ) async {

        let etaKey = match.journeyStop.id

        guard
            forceRefresh || etaResults[etaKey] == nil,
            !loadingRouteIds.contains(etaKey)
        else {
            return
        }

        loadingRouteIds.insert(
            etaKey
        )
        unavailableETAIds.remove(etaKey)
        failedETAIds.remove(etaKey)

        let coordinator = ETARefreshCoordinator.shared
        await coordinator.acquire()

        guard !Task.isCancelled else {
            loadingRouteIds.remove(etaKey)
            await coordinator.release()
            return
        }

        do {
            let result =
                try await RouteETAResolver()
                    .resolve(
                        match: match,
                        modelContext:
                            modelContext
                    )

            if !Task.isCancelled,
                let result
            {
                etaResults[etaKey] = result
            } else if !Task.isCancelled {
                unavailableETAIds.insert(etaKey)
            }
        } catch {
            if !Task.isCancelled {
                failedETAIds.insert(etaKey)
            }
        }

        loadingRouteIds.remove(etaKey)
        await coordinator.release()
    }
}

private struct NearbyLightRailStationView: View {
    let stationEnglish: String
    @State private var entry: LightRailStopCatalogueEntry?
    @State private var failed = false

    var body: some View {
        Group {
            if let entry {
                LightRailStopETAView(
                    stop: entry.stop,
                    servedRouteIDs: entry.routeIDs
                )
            } else if failed {
                ContentUnavailableView("Station Unavailable", systemImage: "lightrail.fill")
            } else {
                ProgressView("Opening Light Rail Stop…")
            }
        }
        .task {
            guard entry == nil, !failed else { return }
            do {
                entry = try LightRailStopCatalogue.load().first { item in
                    item.stop.english.caseInsensitiveCompare(stationEnglish) == .orderedSame
                }
                failed = entry == nil
            } catch {
                failed = true
            }
        }
    }
}

private enum NearbyRailStationKind: String, Codable {
    case mtr
    case lightRail

    func label(for language: TransitLanguage) -> String {
        switch self {
        case .mtr: language.newsText("MTR", "港鐵", "地铁")
        case .lightRail: language.newsText("Light Rail", "輕鐵", "轻铁")
        }
    }
}

private struct NearbyRailStation: Codable {
    let kind: NearbyRailStationKind
    let english: String
    let traditional: String
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    func displayName(for language: TransitLanguage) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese:
            traditional.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? traditional
        }
    }
}

private struct NearbyRailStationMatch: Identifiable {
    let station: NearbyRailStation
    let distanceMeters: CLLocationDistance

    var id: String { "\(station.kind.rawValue)-\(station.english)" }
    var kind: NearbyRailStationKind { station.kind }

    func displayName(for language: TransitLanguage) -> String {
        station.displayName(for: language)
    }
}

private enum NearbyRailStationIndex {
    static let stations: [NearbyRailStation] = {
        guard let url = Bundle.main.url(forResource: "NearbyRailStations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stations = try? JSONDecoder().decode([NearbyRailStation].self, from: data) else {
            return []
        }
        return stations
    }()

    static func nearby(
        to location: CLLocation,
        within distance: CLLocationDistance
    ) -> [NearbyRailStationMatch] {
        stations.compactMap { station in
            let stationLocation = CLLocation(
                latitude: station.latitude,
                longitude: station.longitude
            )
            let stationDistance = location.distance(from: stationLocation)
            guard stationDistance <= distance else { return nil }
            return NearbyRailStationMatch(
                station: station,
                distanceMeters: stationDistance
            )
        }
        .sorted { left, right in left.distanceMeters < right.distanceMeters }
    }
}

private struct NearbyStopGroup: Identifiable {
    let id: String
    let stop: StopEntity
    let matches: [NearbyRouteMatch]
    let distanceMeters: CLLocationDistance
    let stopCodes: [String]
}

#Preview {

    NearbyRouteListView()
        .environment(AppLocationManager())
        .modelContainer(
            for: [
                OperatorEntity.self,
                RouteEntity.self,
                JourneyEntity.self,
                JourneyStopEntity.self,
                StopEntity.self,
                OperatorStopReferenceEntity.self
            ],
            inMemory: true
        )
}
