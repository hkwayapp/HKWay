//
//  StopDetailView.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import SwiftUI
import SwiftData
import MapKit

struct StopDetailView: View {

    let stop: StopEntity
    let journey: JourneyEntity
    let journeyStop: JourneyStopEntity

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.locale)
    private var locale

    @Environment(PurchaseManager.self)
    private var purchaseManager

    @AppStorage("favoriteStopIds")
    private var favoriteStopIdsValue = ""

    @State
    private var showsFavoriteStopLimit = false

    @State
    private var etaResult: RouteETAResult?

    @State
    private var isLoadingETA = false

    @State
    private var operatorStopCoordinate: CLLocationCoordinate2D?

    @State
    private var isMapExpanded = false

    @State
    private var routeMatches: [StopDetailRouteMatch] = []

    @State
    private var routeETAResults: [String: RouteETAResult] = [:]

    @State
    private var loadingRouteIds: Set<String> = []

    @State
    private var unavailableRouteIds: Set<String> = []

    @State
    private var failedRouteIds: Set<String> = []

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
                center: displayedCoordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.005,
                    longitudeDelta: 0.005
                )
            )
        )
    }

    private var displayedCoordinate: CLLocationCoordinate2D {
        operatorStopCoordinate ?? coordinate
    }

    private var displayedCoordinateID: String {
        "\(displayedCoordinate.latitude),\(displayedCoordinate.longitude)"
    }

    private var operatorIds: [String] {
        Array(
            Set(
                journey.route?.operators.flatMap {
                    $0.id.split(separator: "+")
                        .map(String.init)
                } ?? []
            )
        )
        .sorted()
    }

    private var orderedJourneyStops: [JourneyStopEntity] {
        journey.journeyStops.sorted {
            $0.sequence < $1.sequence
        }
    }

    private var currentJourneyStopIndex: Int? {
        orderedJourneyStops.firstIndex {
            $0.id == journeyStop.id
        }
    }

    private var previousJourneyStop: JourneyStopEntity? {
        guard
            let currentJourneyStopIndex,
            currentJourneyStopIndex > orderedJourneyStops.startIndex
        else {
            return nil
        }

        return orderedJourneyStops[
            orderedJourneyStops.index(
                before: currentJourneyStopIndex
            )
        ]
    }

    private var nextJourneyStop: JourneyStopEntity? {
        guard let currentJourneyStopIndex else {
            return nil
        }

        let nextIndex = orderedJourneyStops.index(
            after: currentJourneyStopIndex
        )

        guard nextIndex < orderedJourneyStops.endIndex else {
            return nil
        }

        return orderedJourneyStops[nextIndex]
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

    private var boardingFareText: String? {
        guard let fare = journey.boardingFareCents(
            at: journeyStop.sequence
        ), fare > 0 else {
            return nil
        }

        return String(
            format: "$%.2f",
            Double(fare) / 100
        )
    }

    private var boardingFareTitle: String {
        return switch transitLanguage {
        case .english:
            "Boarding Fare"
        case .traditionalChinese:
            "上車收費"
        case .simplifiedChinese:
            "上车收费"
        }
    }

    private var etaSectionTitle: String {
        let routeNumber = journey.route?.number ?? ""

        return switch transitLanguage {
        case .english:
            "ETA for Route \(routeNumber)"
        case .traditionalChinese:
            "路線\(routeNumber)的預計到站時間"
        case .simplifiedChinese:
            "路线\(routeNumber)的预计到站时间"
        }
    }

    private var adjacentStopsSectionTitle: String {
        let routeNumber = journey.route?.number ?? ""

        return switch transitLanguage {
        case .english:
            "Adjacent Stops on Route \(routeNumber)"
        case .traditionalChinese:
            "路線\(routeNumber)的相鄰車站"
        case .simplifiedChinese:
            "路线\(routeNumber)的相邻车站"
        }
    }

    private var moreRoutesSectionTitle: String {
        switch transitLanguage {
        case .english:
            "More Routes at This Stop"
        case .traditionalChinese:
            "此站的其他路線"
        case .simplifiedChinese:
            "此站的其他路线"
        }
    }

    private var noMoreRoutesText: String {
        switch transitLanguage {
        case .english:
            "No other routes serve this stop"
        case .traditionalChinese:
            "此站沒有其他路線"
        case .simplifiedChinese:
            "此站没有其他路线"
        }
    }

    private var expandMapLabel: String {
        switch transitLanguage {
        case .english:
            "Enlarge map"
        case .traditionalChinese:
            "放大地圖"
        case .simplifiedChinese:
            "放大地图"
        }
    }

    private var closeMapLabel: String {
        switch transitLanguage {
        case .english:
            "Close map"
        case .traditionalChinese:
            "關閉地圖"
        case .simplifiedChinese:
            "关闭地图"
        }
    }

    private func stopCode(for journeyStop: JourneyStopEntity) -> String? {
        journeyStop.publicStopCode
    }

    var body: some View {
        List {
            Section {
                Map(
                    initialPosition: mapPosition,
                    interactionModes: [.pan, .zoom]
                ) {
                    Marker(
                        stop.displayName(for: transitLanguage),
                        coordinate: displayedCoordinate
                    )
                }
                .frame(height: 200)
                .id(displayedCoordinateID)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
                .overlay(alignment: .topTrailing) {
                    Button {
                        isMapExpanded = true
                    } label: {
                        Image(
                            systemName:
                                "arrow.up.left.and.arrow.down.right"
                        )
                        .font(.body.weight(.semibold))
                        .padding(10)
                        .background(
                            .regularMaterial,
                            in: Circle()
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(expandMapLabel)
                    .padding(10)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                CustomLookAroundPreviewView(
                    coordinate: displayedCoordinate
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let boardingFareText {
                Section {
                    LabeledContent(
                        boardingFareTitle,
                        value: boardingFareText
                    )
                    .font(.headline)
                }
                .listRowBackground(
                    Color(uiColor: .systemBackground)
                        .opacity(0.92)
                )
            }

            Section {
                if isLoadingETA {
                    ProgressView("Loading arrivals...")
                } else if let etaResult {
                    TimelineView(
                        .periodic(from: .now, by: 1)
                    ) { context in
                        let upcoming = etaResult.etaRecords
                            .filter {
                                guard let arrival =
                                    $0.estimatedArrival
                                else {
                                    return false
                                }

                                return arrival >= context.date
                            }
                            .sorted {
                                guard
                                    let lhs = $0.estimatedArrival,
                                    let rhs = $1.estimatedArrival
                                else {
                                    return false
                                }

                                return lhs < rhs
                            }
                            .prefix(6)

                        if upcoming.isEmpty {
                            Text("No upcoming arrivals")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(
                                Array(upcoming.enumerated()),
                                id: \.offset
                            ) { _, eta in
                                HStack {
                                    VStack(
                                        alignment: .leading,
                                        spacing: 2
                                    ) {
                                        CustomBadgeView(
                                            operatorId: eta.operatorId,
                                            isCompact: true,
                                            fontSize: 11
                                        )

                                        let destination =
                                            eta.displayDestination(
                                                for: transitLanguage
                                            )

                                        if !destination.isEmpty {
                                            Text(destination)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    if let arrival = eta.estimatedArrival {
                                        Text(
                                            etaText(
                                                for: arrival,
                                                relativeTo: context.date
                                            )
                                        )
                                            .font(.headline)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } else {
                    Text("ETA unavailable")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(etaSectionTitle)
            }
            .listRowBackground(
                Color(uiColor: .systemBackground)
                    .opacity(0.92)
            )

            if previousJourneyStop?.stop != nil ||
                nextJourneyStop?.stop != nil {
                Section {
                    if let previousJourneyStop,
                       let previousStop = previousJourneyStop.stop {
                        adjacentStopLink(
                            title: "Previous Stop",
                            stop: previousStop,
                            journeyStop: previousJourneyStop
                        )
                    }

                    if let nextJourneyStop,
                       let nextStop = nextJourneyStop.stop {
                        adjacentStopLink(
                            title: "Next Stop",
                            stop: nextStop,
                            journeyStop: nextJourneyStop
                        )
                    }
                } header: {
                    Text(adjacentStopsSectionTitle)
                }
                .listRowBackground(
                    Color(uiColor: .systemBackground)
                        .opacity(0.92)
                )
            }

            Section {
                if routeMatches.isEmpty {
                    Text(noMoreRoutesText)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(routeMatches) { match in
                        NavigationLink {
                            RouteDetailView(route: match.route)
                        } label: {
                            RouteRowView(
                                route: match.route,
                                destination: match.destination(
                                    for: transitLanguage
                                ),
                                etaResult: routeETAResults[match.id],
                                isLoadingETA: loadingRouteIds
                                    .contains(match.id),
                                isETAUnavailable: unavailableRouteIds
                                    .contains(match.id),
                                didETAFail: failedRouteIds
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
                                await refreshRouteETA(for: match)
                            }
                        }
                    }
                }
            } header: {
                Text(moreRoutesSectionTitle)
            }
            .listRowBackground(
                Color(uiColor: .systemBackground)
                    .opacity(0.92)
            )
        }
        .listSectionSpacing(14)
        .scrollContentBackground(.hidden)
        .background {
            CustomOperatorBackgroundView(
                operatorIds: operatorIds
            )
        }
        .navigationTitle(
            [
                stop.displayName(for: transitLanguage),
                stopCode(for: journeyStop)
            ]
            .compactMap { $0 }
            .enumerated()
            .map { index, value in
                index == 0 ? value : "(\(value))"
            }
            .joined(separator: " ")
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
        .task(id: journeyStop.id) {
            loadOperatorStopCoordinate()
        }
        .task {
            await loadETA()
        }
        .task {
            loadRoutes()
        }
        .fullScreenCover(
            isPresented: $isMapExpanded
        ) {
            NavigationStack {
                Map(
                    initialPosition: mapPosition,
                    interactionModes: [
                        .pan,
                        .zoom,
                        .rotate
                    ]
                ) {
                    Marker(
                        stop.displayName(
                            for: transitLanguage
                        ),
                        coordinate: displayedCoordinate
                    )
                }
                .id(displayedCoordinateID)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(
                    stop.displayName(
                        for: transitLanguage
                    )
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(
                        placement: .topBarTrailing
                    ) {
                        Button {
                            isMapExpanded = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel(closeMapLabel)
                    }
                }
            }
        }
    }

    private func loadOperatorStopCoordinate() {
        let journeyID = journey.id
        let sequence = journeyStop.sequence
        let descriptor = FetchDescriptor<OperatorStopReferenceEntity>(
            predicate: #Predicate {
                $0.journeyId == journeyID && $0.sequence == sequence
            },
            sortBy: [SortDescriptor(\.id)]
        )
        let references = (try? modelContext.fetch(descriptor)) ?? []
        operatorStopCoordinate = RouteStopLocationResolver.location(
            for: journeyStop,
            journeyID: journeyID,
            references: references
        )?.coordinate
    }

    private func etaText(
        for arrival: Date,
        relativeTo date: Date
    ) -> String {
        let minutes = max(
            0,
            Int(arrival.timeIntervalSince(date) / 60)
        )

        if minutes == 0 {
            switch transitLanguage {
            case .english:
                return "Due"
            case .traditionalChinese:
                return "即將到站"
            case .simplifiedChinese:
                return "即将到站"
            }
        }

        switch transitLanguage {
        case .english:
            return "\(minutes) min"
        case .traditionalChinese:
            return "\(minutes) 分鐘"
        case .simplifiedChinese:
            return "\(minutes) 分钟"
        }
    }

    @MainActor
    private func loadETA() async {
        isLoadingETA = true

        defer {
            isLoadingETA = false
        }

        do {
            etaResult = try await RouteETAResolver().resolve(
                journey: journey,
                journeyStop: journeyStop,
                modelContext: modelContext
            )
        } catch {}
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

        var uniqueMatches: [String: StopDetailRouteMatch] = [:]

        for candidate in journeyStops {
            guard
                candidate.stopPickDrop != "1",
                let candidateJourney = candidate.journey,
                let route = candidateJourney.route
            else {
                continue
            }

            let key = [
                route.id,
                candidateJourney.direction,
                candidateJourney.destinationStop?.id ?? ""
            ].joined(separator: "|")

            let selectedKey = [
                journey.route?.id ?? "",
                journey.direction,
                journey.destinationStop?.id ?? ""
            ].joined(separator: "|")

            guard key != selectedKey else {
                continue
            }

            if uniqueMatches[key] == nil {
                uniqueMatches[key] = StopDetailRouteMatch(
                    id: key,
                    route: route,
                    journey: candidateJourney,
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

    private func refreshRouteETA(
        for match: StopDetailRouteMatch
    ) async {
        while !Task.isCancelled {
            await loadRouteETA(
                for: match,
                forceRefresh: routeETAResults[match.id] != nil
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
    private func loadRouteETA(
        for match: StopDetailRouteMatch,
        forceRefresh: Bool
    ) async {
        guard
            forceRefresh || routeETAResults[match.id] == nil,
            !loadingRouteIds.contains(match.id)
        else {
            return
        }

        loadingRouteIds.insert(match.id)
        unavailableRouteIds.remove(match.id)
        failedRouteIds.remove(match.id)

        let coordinator = ETARefreshCoordinator.shared
        await coordinator.acquire()

        guard !Task.isCancelled else {
            loadingRouteIds.remove(match.id)
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
                    routeETAResults[match.id] = result
                } else if routeETAResults[match.id] == nil {
                    unavailableRouteIds.insert(match.id)
                }
            }
        } catch {
            if !Task.isCancelled,
               routeETAResults[match.id] == nil {
                failedRouteIds.insert(match.id)
            }
        }

        loadingRouteIds.remove(match.id)
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

    private func adjacentStopLink(
        title: LocalizedStringKey,
        stop: StopEntity,
        journeyStop: JourneyStopEntity
    ) -> some View {
        NavigationLink {
            StopDetailView(
                stop: stop,
                journey: journey,
                journeyStop: journeyStop
            )
        } label: {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.secondary)

                    Text(verbatim: transitLanguage == .english ? ":" : "：")
                        .foregroundStyle(.secondary)

                    Text(
                        stop.displayName(
                            for: transitLanguage
                        )
                    )
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                    if let code = stopCode(for: journeyStop) {
                        Text(verbatim: "(\(code))")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct StopDetailRouteMatch: Identifiable {
    let id: String
    let route: RouteEntity
    let journey: JourneyEntity
    let journeyStop: JourneyStopEntity

    func destination(for language: TransitLanguage) -> String {
        journey.destinationStop?.displayName(for: language)
            ?? route.displayDestination(for: language)
    }
}
