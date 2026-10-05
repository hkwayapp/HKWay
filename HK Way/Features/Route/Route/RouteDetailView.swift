//
//  RouteDetailView.swift
//  HK Way
//
//  Created by Ken on 17/8/2026.
//

import SwiftUI
import SwiftData
import CoreLocation

struct RouteDetailView: View {

    let route: RouteEntity
    @Query private var operatorStopReferences: [OperatorStopReferenceEntity]

    init(route: RouteEntity) {
        self.route = route
        let journeyIDs = route.journeys.map(\.id)
        _operatorStopReferences = Query(filter: #Predicate<OperatorStopReferenceEntity> {
            journeyIDs.contains($0.journeyId)
        })
    }

    @Query(sort: \RouteEntity.number)
    private var allRoutes: [RouteEntity]

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.locale)
    private var locale

    private func stopCode(
        for journey: JourneyEntity,
        journeyStop: JourneyStopEntity
    ) -> String? {
        journeyStop.publicStopCode
    }

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    @State
    private var selectedSection:
        RouteDetailSection = .routeDetails

    @State
    private var highlightsJourneyETAOnSelection = false

    @State
    private var isFareInformationHighlighted = false

    @State
    private var isCurrentStopHighlighted = false

    private let fareInformationAnchor = "fare-information"
    private let currentStopAnchor = "current-stop"

    @Environment(AppLocationManager.self)
    private var locationManager

    @Environment(PurchaseManager.self)
    private var purchaseManager

    @State
    private var currentStopETAResults:
        [String: RouteETAResult] = [:]

    @State
    private var loadingCurrentStopIds:
        Set<String> = []

    @State
    private var unavailableCurrentStopIds:
        Set<String> = []

    @State
    private var failedCurrentStopIds:
        Set<String> = []

    @AppStorage("favoriteRouteIds")
    private var favoriteRouteIdsValue = ""

    @State
    private var showsFavoriteRouteLimit = false

    @State
    private var showsWatchJourneySetup = false

    @State
    private var liveActivityStatusMessage: String?

    private var journeys: [JourneyEntity] {
        route.journeys.sorted {
            $0.direction < $1.direction
        }
    }

    private var isMoreThanOneKilometerAway: Bool {
        guard let userLocation = locationManager.location else {
            return false
        }

        let nearestDistance = journeys
            .compactMap { nearestJourneyStop(for: $0) }
            .map { distance(from: userLocation, to: $0) }
            .min()

        return nearestDistance.map { $0 > 1_000 } ?? false
    }

    private var isCircular: Bool {
        route.destinationEnglish
            .localizedCaseInsensitiveContains(
                "(CIRCULAR)"
            )
    }

    private var circularDestination: String {
        route.displayDestination(
            for: transitLanguage
        )
        .transitDisplayName
    }

    private var operatorRows: [[String]] {
        let operatorIds = Array(
            Set(
                route.operators.flatMap {
                    $0.id.split(separator: "+")
                        .map(String.init)
                }
            )
        )
        .sorted()

        return stride(
            from: 0,
            to: operatorIds.count,
            by: 2
        )
        .map { index in
            Array(
                operatorIds[
                    index..<min(
                        index + 2,
                        operatorIds.count
                    )
                ]
            )
        }
    }

    private var displayedDestination: String {
        isCircular
            ? circularDestination.transitDisplayName
            : route.displayDestination(for: transitLanguage)
    }

    private var journeyAlertAccessibilityLabel: String {
        switch transitLanguage {
        case .english: "Set Journey Alert"
        case .traditionalChinese: "設定行程提示"
        case .simplifiedChinese: "设置行程提醒"
        }
    }

    private var adultFareText: String? {
        let fares = Array(
            Set(
                journeys.compactMap(\.adultFullFareCents)
            )
        )
        .sorted()

        guard let minimumFare = fares.first else {
            return nil
        }

        if let maximumFare = fares.last,
           maximumFare != minimumFare {
            return "\(fareText(minimumFare))–\(fareText(maximumFare))"
        }

        return fareText(minimumFare)
    }

    private func fareText(_ cents: Int) -> String {
        let amount = String(
            format: "%.2f",
            Double(cents) / 100
        )

        return "$\(amount)"
    }

    private var sectionFareText: String? {
        guard let minimumFare = journeys
            .compactMap(\.sectionFareTiers)
            .flatMap({ $0 })
            .map(\.fareCents)
            .filter({ $0 > 0 })
            .min() else {
            return nil
        }

        let amount = fareText(minimumFare)

        return transitLanguage == .english
            ? "From \(amount)"
            : "\(amount)起"
    }

    private var sectionFareTitle: String {
        switch transitLanguage {
        case .english:
            "Section Fare"
        case .traditionalChinese:
            "分段收費"
        case .simplifiedChinese:
            "分段收费"
        }
    }

    private var scheduledJourneyTimeText: String? {
        let durations = Array(
            Set(
                journeys.compactMap(\.scheduledDurationMinutes)
            )
        )
        .sorted()

        guard let minimum = durations.first else {
            return nil
        }

        let value: String
        if let maximum = durations.last,
           maximum != minimum {
            value = "\(minimum)–\(maximum)"
        } else {
            value = "\(minimum)"
        }

        switch transitLanguage {
        case .english:
            return "\(value) min"
        case .traditionalChinese:
            return "\(value) 分鐘"
        case .simplifiedChinese:
            return "\(value) 分钟"
        }
    }

    private var scheduledJourneyTimeTitle: String {
        switch transitLanguage {
        case .english:
            "Estimated Journey Time"
        case .traditionalChinese:
            "預計行程時間"
        case .simplifiedChinese:
            "预计行程时间"
        }
    }

    private var fareInformationText: (
        title: String,
        source: String,
        fullFare: String,
        sectionFare: String,
        boardingFare: String,
        updated: String
    ) {
        switch transitLanguage {
        case .english:
            return (
                "Fare Information",
                "Fares are provided by the Hong Kong Transport Department.",
                "Full Fare: the adult fare charged from the route origin.",
                "Section Fare: the lowest published reduced fare on this route.",
                "Boarding Fare: the fare applicable from the selected stop.",
                "Fare data updated"
            )
        case .traditionalChinese:
            return (
                "收費資料",
                "車費資料由香港運輸署提供。",
                "全程收費：由路線起點上車的成人車費。",
                "分段收費：此路線已公布的最低優惠車費。",
                "上車收費：由所選車站上車適用的車費。",
                "車費資料更新日期"
            )
        case .simplifiedChinese:
            return (
                "收费资料",
                "车费资料由香港运输署提供。",
                "全程收费：由路线起点上车的成人车费。",
                "分段收费：此路线已公布的最低优惠车费。",
                "上车收费：由所选车站上车适用的车费。",
                "车费资料更新日期"
            )
        }
    }

    private var fareDataUpdatedDate: String? {
        DatasetVersionStore().fareDataUpdatedAt.map {
            String($0.prefix(10))
        }
    }

    private var fareInformationAccessibilityHint: String {
        switch transitLanguage {
        case .english:
            "Shows fare information"
        case .traditionalChinese:
            "顯示收費資料"
        case .simplifiedChinese:
            "显示收费资料"
        }
    }

    private var favoriteRouteIds: Set<String> {
        Set(
            favoriteRouteIdsValue
                .split(separator: "\n")
                .map(String.init)
        )
    }

    private var infoCardColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        return [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible())
        ]
    }

    private var favoriteJourneys: [JourneyEntity] {
        var journeysByDirection: [String: JourneyEntity] = [:]

        for journey in journeys {
            if let existing = journeysByDirection[journey.direction],
               existing.journeyStops.count >= journey.journeyStops.count {
                continue
            }
            journeysByDirection[journey.direction] = journey
        }

        return journeysByDirection.values.sorted {
            $0.direction.localizedStandardCompare($1.direction)
                == .orderedAscending
        }
    }

    private func favoriteID(for journey: JourneyEntity) -> String {
        "\(route.id)|\(journey.direction)"
    }

    private var legacyFavoriteJourneyID: String? {
        let routeOrigin = normalizedEndpoint(route.originEnglish)
        let routeDestination = normalizedEndpoint(route.destinationEnglish)

        return favoriteJourneys.first { journey in
            let stops = journey.journeyStops.sorted { $0.sequence < $1.sequence }
            let origin = normalizedEndpoint(
                stops.first?.stop?.nameEnglish ?? ""
            )
            let destination = normalizedEndpoint(
                stops.last?.stop?.nameEnglish ?? ""
            )
            return origin == routeOrigin && destination == routeDestination
        }?.id ?? favoriteJourneys.first?.id
    }

    private func isFavorite(_ journey: JourneyEntity) -> Bool {
        favoriteRouteIds.contains(favoriteID(for: journey))
            || (favoriteRouteIds.contains(route.id)
                && legacyFavoriteJourneyID == journey.id)
    }

    private var reverseRoute: RouteEntity? {
        guard !isCircular else { return nil }

        let currentOperatorIds = operatorIds(for: route)
        let currentOrigin = normalizedEndpoint(route.originEnglish)
        let currentDestination = normalizedEndpoint(
            route.destinationEnglish
        )

        return allRoutes.first { candidate in
            candidate.id != route.id
                && candidate.number.caseInsensitiveCompare(
                    route.number
                ) == .orderedSame
                && !currentOperatorIds.isDisjoint(
                    with: operatorIds(for: candidate)
                )
                && normalizedEndpoint(candidate.originEnglish)
                    == currentDestination
                && normalizedEndpoint(candidate.destinationEnglish)
                    == currentOrigin
        }
    }

    var body: some View {

        VStack(spacing: 0) {

            Picker(
                "Route Section",
                selection: Binding(
                    get: { selectedSection },
                    set: { newValue in
                        highlightsJourneyETAOnSelection = false
                        selectedSection = newValue
                    }
                )
            ) {

                ForEach(
                    RouteDetailSection.allCases
                ) { section in

                    Text(
                        LocalizedStringKey(
                            section.title
                        )
                    )
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            switch selectedSection {
            case .routeDetails:
                routeDetailsContent

            case .stops:
                journeyList
            }
        }
        .navigationTitle(
            "Route \(route.number)"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .background {
            CustomOperatorBackgroundView(
                operatorIds:
                    operatorRows.flatMap { $0 }
            )
        }
        .toolbar {

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsWatchJourneySetup = true
                } label: {
                    Image(systemName: "bell")
                }
                .accessibilityLabel(journeyAlertAccessibilityLabel)

                if let reverseRoute {
                    NavigationLink {
                        RouteDetailView(route: reverseRoute)
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .accessibilityLabel("Reverse Direction")
                }

                if favoriteJourneys.count == 1,
                   let journey = favoriteJourneys.first {
                    Button {
                        toggleFavorite(journey)
                    } label: {
                        Image(
                            systemName: isFavorite(journey)
                                ? "bookmark.fill"
                                : "bookmark"
                        )
                    }
                    .accessibilityLabel(
                        isFavorite(journey)
                            ? "Remove from Favorites"
                            : "Add to Favorites"
                    )
                } else if !favoriteJourneys.isEmpty {
                    Menu {
                        ForEach(favoriteJourneys) { journey in
                            Button {
                                toggleFavorite(journey)
                            } label: {
                                Label(
                                    directionName(for: journey),
                                    systemImage: isFavorite(journey)
                                        ? "bookmark.fill"
                                        : "bookmark"
                                )
                            }
                        }
                    } label: {
                        Image(
                            systemName: favoriteJourneys.contains(where: isFavorite)
                                ? "bookmark.fill"
                                : "bookmark"
                        )
                    }
                    .accessibilityLabel("Choose Favorite Direction")
                }
            }
        }
        .alert(
            "Favorite Route Limit Reached",
            isPresented: $showsFavoriteRouteLimit
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Free allows up to 5 favorite routes. Remove one before adding another, or upgrade to Full for unlimited favorites.")
        }
        .sheet(isPresented: $showsWatchJourneySetup) {
            WatchJourneySetupView(
                route: route,
                journeys: journeys,
                language: transitLanguage,
                userLocation: locationManager.location
            ) { snapshot, originSequence, destinationSequence in
                JourneyAlertManager.shared.start(
                    snapshot: snapshot,
                    originSequence: originSequence,
                    destinationSequence: destinationSequence,
                    language: transitLanguage
                )
                liveActivityStatusMessage = JourneyAlertManager.shared.liveActivityStatusMessage
                WatchSyncManager.shared.startJourney(
                    snapshot,
                    originSequence: originSequence,
                    destinationSequence: destinationSequence
                )
            }
        }
        .alert(
            String(localized: "Live Activity Unavailable", locale: locale),
            isPresented: Binding(
                get: { liveActivityStatusMessage != nil },
                set: { if !$0 { liveActivityStatusMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { liveActivityStatusMessage = nil }
        } message: {
            Text(liveActivityStatusMessage ?? "")
        }
        .task {
            locationManager.requestLocation(force: true)
        }
    }

    private func operatorIds(
        for route: RouteEntity
    ) -> Set<String> {
        Set(
            route.operators.flatMap {
                $0.id.split(separator: "+").map(String.init)
            }
        )
    }

    private func normalizedEndpoint(_ name: String) -> String {
        name
            .replacingOccurrences(
                of: "(CIRCULAR)",
                with: "",
                options: .caseInsensitive
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var routeDetailsContent:
        some View {

        ScrollViewReader { proxy in
            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                CustomRouteDetailedBanner(
                    routeNumber: route.number,
                    origin: route.displayOrigin(for: transitLanguage),
                    destination: displayedDestination
                )

                LazyVGrid(
                    columns: infoCardColumns,
                    spacing: 10
                ) {

                    CustomInfoCardView(
                        title: "Operator"
                    ) {
                        VStack(spacing: 6) {
                            ForEach(
                                operatorRows,
                                id: \.self
                            ) { row in
                                HStack(spacing: 4) {
                                    ForEach(row, id: \.self) {
                                        CustomBadgeView(
                                            operatorId: $0,
                                            isCompact: true,
                                            fontSize: 13
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        highlightsJourneyETAOnSelection = true
                        if accessibilityReduceMotion {
                            selectedSection = .stops
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedSection = .stops
                            }
                        }
                    } label: {
                        CustomInfoCardView(
                            title: "Journeys",
                            message: "\(journeys.count)"
                        )
                    }
                    .buttonStyle(.plain)

                    CustomInfoCardView(
                        title: "Route Type",
                        message: isCircular
                            ? "Circular"
                            : "Direct"
                    )

                    if let adultFareText {
                        Button {
                            showFareInformation(using: proxy)
                        } label: {
                            CustomInfoCardView(
                                title: "Adult Fare",
                                message: adultFareText
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            fareInformationAccessibilityHint
                        )
                    }

                    if let sectionFareText {
                        Button {
                            showFareInformation(using: proxy)
                        } label: {
                            CustomInfoCardView(
                                title: sectionFareTitle,
                                message: sectionFareText
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            fareInformationAccessibilityHint
                        )
                    }

                    if let scheduledJourneyTimeText {
                        Button {
                            showCurrentStop(using: proxy)
                        } label: {
                            CustomInfoCardView(
                                title: scheduledJourneyTimeTitle,
                                message: scheduledJourneyTimeText
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !journeys.isEmpty {
                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {
                        if isMoreThanOneKilometerAway {
                            Label(
                                "You are over 1 km away from this route",
                                systemImage: "location.slash.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(.orange)
                            .padding(16)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .customInfoCardSurface(
                                showsShadow: false
                            )
                        }

                        adjacentStopsCard(
                            title: "Previous Stop",
                            offset: -1
                        )

                        Text("Nearest Route Stop")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .id(currentStopAnchor)

                        ForEach(journeys) { journey in
                            let nearestStop =
                                nearestJourneyStop(
                                    for: journey
                                )

                            NavigationLink {
                                DeferredJourneyStopListView(
                                    journey: journey
                                )
                            } label: {
                                CustomCurrentStopETAView(
                                    directionName:
                                        directionName(
                                            for: journey
                                        ),
                                    stopName: nearestStop?
                                        .stop?
                                        .displayName(for: transitLanguage),
                                    stopCode: nearestStop.flatMap {
                                        stopCode(
                                            for: journey,
                                            journeyStop: $0
                                        )
                                    },
                                    etaResult: nearestStop.flatMap {
                                        currentStopETAResults[$0.id]
                                    },
                                    isLoading: nearestStop.map {
                                        loadingCurrentStopIds
                                            .contains($0.id)
                                    } ?? false,
                                    isUnavailable: nearestStop.map {
                                        unavailableCurrentStopIds
                                            .contains($0.id)
                                    } ?? false,
                                    didFail: nearestStop.map {
                                        failedCurrentStopIds
                                            .contains($0.id)
                                    } ?? false
                                )
                                .padding(16)
                                .customInfoCardSurface(
                                    showsShadow: false
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(
                                            Color.accentColor,
                                            lineWidth: isCurrentStopHighlighted
                                                ? 3
                                                : 0
                                        )
                                }
                                .animation(
                                    accessibilityReduceMotion
                                        ? nil
                                        : .easeInOut(duration: 0.2),
                                    value: isCurrentStopHighlighted
                                )
                                .task(id: nearestStop?.id) {
                                    guard let nearestStop else {
                                        return
                                    }

                                    await loadCurrentStopETA(
                                        journey: journey,
                                        journeyStop: nearestStop
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        adjacentStopsCard(
                            title: "Next Stop",
                            offset: 1
                        )

                        if locationManager.location != nil {
                            Text(
                                "The stops shown above are the closest stops for each journey, but they may not be near your current location."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .center
                            )
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        }
                    }
                }

                if adultFareText != nil || sectionFareText != nil {
                    fareInformationCard
                        .id(fareInformationAnchor)
                }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var fareInformationCard: some View {
        let text = fareInformationText

        return VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Label(
                text.title,
                systemImage: "dollarsign.circle"
            )
            .font(.headline)

            Text(text.source)
            Text(text.fullFare)
            Text(text.sectionFare)
            Text(text.boardingFare)

            if let fareDataUpdatedDate {
                Text(
                    "\(text.updated): " +
                        fareDataUpdatedDate
                )
                .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(16)
        .customInfoCardSurface(
            showsShadow: false
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    Color.accentColor,
                    lineWidth: isFareInformationHighlighted
                        ? 3
                        : 0
                )
        }
        .animation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 0.2),
            value: isFareInformationHighlighted
        )
    }

    private func showFareInformation(
        using proxy: ScrollViewProxy
    ) {
        if accessibilityReduceMotion {
            proxy.scrollTo(
                fareInformationAnchor,
                anchor: .center
            )
        } else {
            withAnimation(.easeInOut(duration: 0.45)) {
                proxy.scrollTo(
                    fareInformationAnchor,
                    anchor: .center
                )
            }
        }

        isFareInformationHighlighted = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            isFareInformationHighlighted = false
        }
    }

    private func showCurrentStop(
        using proxy: ScrollViewProxy
    ) {
        if accessibilityReduceMotion {
            proxy.scrollTo(
                currentStopAnchor,
                anchor: .top
            )
        } else {
            withAnimation(.easeInOut(duration: 0.45)) {
                proxy.scrollTo(
                    currentStopAnchor,
                    anchor: .top
                )
            }
        }

        isCurrentStopHighlighted = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            isCurrentStopHighlighted = false
        }
    }

    private var journeyList: some View {

        List {

            Section {

                if journeys.isEmpty {

                    Text("No journeys")
                        .foregroundStyle(
                            .secondary
                        )

                } else {

                    ForEach(journeys) { journey in

                        NavigationLink {

                            DeferredJourneyStopListView(
                                journey: journey,
                                highlightsNearestETAOnAppear:
                                    highlightsJourneyETAOnSelection
                            )

                        } label: {

                            JourneySummaryView(
                                journey: journey,
                                isCircular:
                                    isCircular,
                                circularDestination:
                                    circularDestination
                            )
                        }
                    }
                }

            } header: {
                Text("Journeys")
            }
            .listRowBackground(
                Color(uiColor: .systemBackground)
                    .opacity(0.92)
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func orderedStops(
        for journey: JourneyEntity
    ) -> [JourneyStopEntity] {
        journey.journeyStops.sorted {
            $0.sequence < $1.sequence
        }
    }

    private func directionName(
        for journey: JourneyEntity
    ) -> String {
        if isCircular {
            return circularDestination
        }

        return orderedStops(for: journey)
            .last?
            .stop?
            .displayName(for: transitLanguage)
            ?? String(
                localized: "Destination unavailable",
                locale: locale
            )
    }

    private func nearestJourneyStop(
        for journey: JourneyEntity
    ) -> JourneyStopEntity? {
        guard let userLocation =
            locationManager.location
        else {
            return nil
        }

        return orderedStops(for: journey)
            .filter { $0.stop != nil }
            .min { lhs, rhs in
                distance(from: userLocation, to: lhs) <
                    distance(from: userLocation, to: rhs)
            }
    }

    private func adjacentJourneyStop(
        for journey: JourneyEntity,
        offset: Int
    ) -> JourneyStopEntity? {
        guard
            let nearestStop = nearestJourneyStop(for: journey)
        else {
            return nil
        }

        let stops = orderedStops(for: journey)
            .filter { $0.stop != nil }

        guard let currentIndex = stops.firstIndex(
            where: { $0.id == nearestStop.id }
        ) else {
            return nil
        }

        let targetIndex = currentIndex + offset

        if stops.indices.contains(targetIndex) {
            return stops[targetIndex]
        }

        guard isCircular, stops.count > 2 else {
            return nil
        }

        if offset < 0 {
            return stops[stops.count - 2]
        }

        return stops[1]
    }

    @ViewBuilder
    private func adjacentStopsCard(
        title: LocalizedStringKey,
        offset: Int
    ) -> some View {
        let hasAdjacentStop = journeys.contains { journey in
            adjacentJourneyStop(
                for: journey,
                offset: offset
            ) != nil
        }

        if hasAdjacentStop {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(journeys) { journey in
                        if let journeyStop = adjacentJourneyStop(
                            for: journey,
                            offset: offset
                        ) {
                            NavigationLink {
                                DeferredJourneyStopListView(journey: journey)
                            } label: {
                                AdjacentStopETARow(
                                    stopName: journeyStop.stop?
                                        .displayName(for: transitLanguage)
                                        ?? String(localized: "Stop unavailable", locale: locale),
                                    stopCode: stopCode(
                                        for: journey,
                                        journeyStop: journeyStop
                                    ),
                                    directionName: directionName(for: journey),
                                    etaResult: currentStopETAResults[journeyStop.id],
                                    isLoading: loadingCurrentStopIds.contains(journeyStop.id),
                                    isUnavailable: unavailableCurrentStopIds.contains(journeyStop.id),
                                    didFail: failedCurrentStopIds.contains(journeyStop.id)
                                )
                                .task(id: journeyStop.id) {
                                    await loadCurrentStopETA(
                                        journey: journey,
                                        journeyStop: journeyStop
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .customInfoCardSurface(
                    showsShadow: false
                )
            }
        }
    }

    private func distance(
        from userLocation: CLLocation,
        to journeyStop: JourneyStopEntity
    ) -> CLLocationDistance {
        let journeyID = journeyStop.journey?.id ?? route.journeys.first {
            $0.journeyStops.contains { $0.id == journeyStop.id }
        }?.id
        guard let stopLocation = RouteStopLocationResolver.location(
            for: journeyStop, journeyID: journeyID, references: operatorStopReferences
        ) else {
            return .greatestFiniteMagnitude
        }

        return userLocation.distance(from: stopLocation)
    }

    @MainActor
    private func loadCurrentStopETA(
        journey: JourneyEntity,
        journeyStop: JourneyStopEntity
    ) async {
        let stopId = journeyStop.id

        guard
            currentStopETAResults[stopId] == nil,
            !loadingCurrentStopIds.contains(stopId),
            !unavailableCurrentStopIds.contains(stopId),
            !failedCurrentStopIds.contains(stopId)
        else {
            return
        }

        loadingCurrentStopIds.insert(stopId)

        defer {
            loadingCurrentStopIds.remove(stopId)
        }

        do {
            let result = try await RouteETAResolver()
                .resolve(
                    journey: journey,
                    journeyStop: journeyStop,
                    modelContext: modelContext
                )

            if let result {
                currentStopETAResults[stopId] = result
            } else {
                unavailableCurrentStopIds.insert(stopId)
            }

        } catch {
            failedCurrentStopIds.insert(stopId)
        }
    }

    private func toggleFavorite(_ journey: JourneyEntity) {
        var updatedIds = favoriteRouteIds
        let favoriteID = favoriteID(for: journey)

        if isFavorite(journey) {
            updatedIds.remove(favoriteID)
            updatedIds.remove(route.id)
        } else {
            let policy = AppAccessPolicy(tier: purchaseManager.accessTier)
            guard policy.allowsAddition(
                to: .favoriteRoutes,
                existingCount: updatedIds.count,
                isAlreadySaved: false
            ) else {
                showsFavoriteRouteLimit = true
                return
            }
            updatedIds.insert(favoriteID)
        }

        favoriteRouteIdsValue = updatedIds
            .sorted()
            .joined(separator: "\n")
    }

}

private struct AdjacentStopETARow: View {
    let stopName: String
    let stopCode: String?
    let directionName: String
    let etaResult: RouteETAResult?
    let isLoading: Bool
    let isUnavailable: Bool
    let didFail: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(stopName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    if let stopCode {
                        Text(verbatim: "(\(stopCode))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Towards \(directionName)")
                    .bold()
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            etaContent
        }
    }

    @ViewBuilder
    private var etaContent: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
        } else if isUnavailable {
            statusText("Unavailable")
        } else if didFail {
            statusText("Error")
        } else if let etaResult {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let arrival = nextArrival(
                    in: etaResult,
                    at: context.date
                ) {
                    Text(
                        arrival,
                        format: .dateTime
                            .hour()
                            .minute()
                    )
                    .fontWeight(.semibold)
                    .monospacedDigit()
                } else {
                    statusText("No ETA")
                }
            }
        } else {
            statusText("Waiting for ETA...")
        }
    }

    private func nextArrival(
        in etaResult: RouteETAResult,
        at date: Date
    ) -> Date? {
        var nextArrival: Date?

        for record in etaResult.etaRecords {
            guard
                let arrival = record.estimatedArrival,
                arrival >= date
            else {
                continue
            }

            if let currentArrival = nextArrival {
                if arrival < currentArrival {
                    nextArrival = arrival
                }
            } else {
                nextArrival = arrival
            }
        }

        return nextArrival
    }

    private func statusText(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private enum RouteDetailSection:
    String,
    CaseIterable,
    Identifiable {

    case routeDetails
    case stops

    var id: Self { self }

    var title: String {
        switch self {
        case .routeDetails:
            "Route Details"
        case .stops:
            "Journeys"
        }
    }
}
