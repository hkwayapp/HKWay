//
//  JourneyStopListView.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//d

import SwiftUI
import SwiftData
import CoreLocation

/// Lets the navigation transition complete before constructing the relationship-heavy
/// stop list. This keeps route-card taps responsive on large imported datasets.
struct DeferredJourneyStopListView: View {
    let journey: JourneyEntity
    var highlightsNearestETAOnAppear = false
    var onSelectStop: ((JourneyStopEntity) -> Void)?

    @State private var showsJourney = false

    var body: some View {
        Group {
            if showsJourney {
                JourneyStopListView(
                    journey: journey,
                    highlightsNearestETAOnAppear: highlightsNearestETAOnAppear,
                    onSelectStop: onSelectStop
                )
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            showsJourney = true
        }
    }
}

struct JourneyStopListView: View {

    private let initialJourney: JourneyEntity
    var highlightsNearestETAOnAppear = false
    var onSelectStop: ((JourneyStopEntity) -> Void)?

    @State
    private var selectedJourney: JourneyEntity?

    init(
        journey: JourneyEntity,
        highlightsNearestETAOnAppear: Bool = false,
        onSelectStop: ((JourneyStopEntity) -> Void)? = nil
    ) {
        initialJourney = journey
        self.highlightsNearestETAOnAppear = highlightsNearestETAOnAppear
        self.onSelectStop = onSelectStop
    }

    private var journey: JourneyEntity {
        selectedJourney ?? initialJourney
    }

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.locale)
    private var locale

    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    private func stopCode(for journeyStop: JourneyStopEntity) -> String? {
        journeyStop.publicStopCode
    }

    private func boardingFareText(
        for journeyStop: JourneyStopEntity
    ) -> String? {
        guard journeyStop.stopPickDrop != "1" else {
            return nil
        }

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

    @State
    private var etaResults:
        [String: RouteETAResult] = [:]

    @State
    private var loadingStopIds:
        Set<String> = []

    @State
    private var unavailableStopIds:
        Set<String> = []

    @State
    private var failedStopIds:
        Set<String> = []

    @State
    private var isNearestETAHighlighted = false

    @State
    private var didApplyInitialETAHighlight = false

    @State
    private var showsWatchJourneySetup = false

    @State
    private var liveActivityStatusMessage: String?

    @State
    private var reverseJourney: JourneyEntity?

    private let nearestETAAnchor = "nearest-stop-eta"

    @Environment(AppLocationManager.self)
    private var locationManager

    private var orderedStops:
        [JourneyStopEntity] {

        journey.journeyStops.sorted {
            $0.sequence < $1.sequence
        }
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

    private var nearestJourneyStop:
        JourneyStopEntity? {

        guard let userLocation =
            locationManager.location
        else {
            return nil
        }

        return orderedStops
            .filter {
                $0.stop != nil && $0.stopPickDrop != "1"
            }
            .min { lhs, rhs in
                distance(from: userLocation, to: lhs) <
                    distance(from: userLocation, to: rhs)
            }
    }

    private var isMoreThanOneKilometerAway: Bool {
        guard
            let userLocation = locationManager.location,
            let nearestJourneyStop
        else {
            return false
        }

        return distance(
            from: userLocation,
            to: nearestJourneyStop
        ) > 1_000
    }

    private var navigationTitleText: String {
        guard let routeNumber = journey.route?.number else {
            switch transitLanguage {
            case .english:
                return "Journey"
            case .traditionalChinese:
                return "行程"
            case .simplifiedChinese:
                return "行程"
            }
        }

        switch transitLanguage {
        case .english:
            return "Route \(routeNumber)"
        case .traditionalChinese:
            return "路線\(routeNumber)"
        case .simplifiedChinese:
            return "路线\(routeNumber)"
        }
    }

    private var journeyAlertAccessibilityLabel: String {
        switch transitLanguage {
        case .english: "Set Journey Alert"
        case .traditionalChinese: "設定行程提示"
        case .simplifiedChinese: "设置行程提醒"
        }
    }

    private var reverseDirectionAccessibilityLabel: String {
        switch transitLanguage {
        case .english: "Reverse Direction"
        case .traditionalChinese: "相反方向"
        case .simplifiedChinese: "相反方向"
        }
    }

    private func findReverseJourney(
        for journey: JourneyEntity
    ) -> JourneyEntity? {
        let stops = journey.journeyStops.sorted { $0.sequence < $1.sequence }

        guard let route = journey.route,
              let currentOrigin = stops.first?.stop?.nameEnglish,
              let currentDestination = stops.last?.stop?.nameEnglish,
              normalizedEndpoint(currentOrigin) != normalizedEndpoint(currentDestination)
        else { return nil }

        let currentOperatorIds = operatorIds(for: route)
        let routeNumber = route.number
        let descriptor = FetchDescriptor<RouteEntity>(
            predicate: #Predicate { $0.number == routeNumber }
        )
        let matchingRoutes = (try? modelContext.fetch(descriptor)) ?? []
        return matchingRoutes
            .filter {
                $0.number.caseInsensitiveCompare(route.number) == .orderedSame
                    && !currentOperatorIds.isDisjoint(with: operatorIds(for: $0))
            }
            .flatMap(\.journeys)
            .filter { candidate in
                guard candidate.id != journey.id else { return false }
                let stops = candidate.journeyStops.sorted { $0.sequence < $1.sequence }
                guard let origin = stops.first?.stop?.nameEnglish,
                      let destination = stops.last?.stop?.nameEnglish else {
                    return false
                }
                return normalizedEndpoint(origin) == normalizedEndpoint(currentDestination)
                    && normalizedEndpoint(destination) == normalizedEndpoint(currentOrigin)
            }
            .max { $0.journeyStops.count < $1.journeyStops.count }
    }

    var body: some View {

        ScrollViewReader { scrollProxy in
            List {

            // MARK: - Journey Summary

            Section {
                CustomRouteBannerView(
                    routeNumber: journey.route?.number,
                    origin: orderedStops.first?
                        .stop?
                        .displayName(for: transitLanguage)
                        ?? String(
                            localized: "Origin unavailable",
                            locale: locale
                        ),
                    destination: orderedStops.last?
                        .stop?
                        .displayName(for: transitLanguage)
                        ?? String(
                            localized: "Destination unavailable",
                            locale: locale
                        )
                )
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                )
            )

            // MARK: - Map

            Section {

                NavigationLink {

                    JourneyMapView(
                        journey: journey
                    )

                } label: {

                    Label(
                        "View Journey Map",
                        systemImage: "map"
                    )
                }
            }
            .listRowBackground(
                Color(uiColor: .systemBackground)
                    .opacity(0.92)
            )

            // MARK: - Nearest Stop

            if isMoreThanOneKilometerAway {
                Section {
                    Label(
                        "You are over 1 km away from this route",
                        systemImage: "location.slash.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.orange)
                }
                .listRowBackground(
                    Color(uiColor: .systemBackground)
                        .opacity(0.92)
                )
            }

            if !isMoreThanOneKilometerAway {
                Section {
                Button {
                    scrollToNearestStop(
                        using: scrollProxy
                    )
                } label: {
                    CustomCurrentStopETAView(
                        stopName: nearestJourneyStop?
                            .stop?
                            .displayName(for: transitLanguage),
                        stopCode: nearestJourneyStop.flatMap(stopCode),
                        showsStopName: false,
                        etaResult: nearestJourneyStop.flatMap {
                            etaResults[$0.id]
                        },
                        isLoading: nearestJourneyStop.map {
                            loadingStopIds.contains($0.id)
                        } ?? false,
                        isUnavailable: nearestJourneyStop.map {
                            unavailableStopIds.contains($0.id)
                        } ?? false,
                        didFail: nearestJourneyStop.map {
                            failedStopIds.contains($0.id)
                        } ?? false
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(nearestJourneyStop == nil)
                .id(nearestETAAnchor)
                .task(id: nearestJourneyStop?.id) {
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }

                    guard let nearestJourneyStop else {
                        return
                    }

                    await loadETA(
                        for: nearestJourneyStop
                    )

                    guard
                        highlightsNearestETAOnAppear,
                        !didApplyInitialETAHighlight
                    else {
                        return
                    }

                    didApplyInitialETAHighlight = true

                    if accessibilityReduceMotion {
                        scrollProxy.scrollTo(
                            nearestETAAnchor,
                            anchor: .center
                        )
                    } else {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            scrollProxy.scrollTo(
                                nearestETAAnchor,
                                anchor: .center
                            )
                        }
                    }

                    isNearestETAHighlighted = true

                    try? await Task.sleep(for: .seconds(1.2))
                    isNearestETAHighlighted = false
                }
            } header: {
                Button {
                    scrollToNearestStop(
                        using: scrollProxy
                    )
                } label: {
                    Group {
                        if let stopName = nearestJourneyStop?
                            .stop?
                            .displayName(for: transitLanguage) {
                            HStack(spacing: 0) {
                                Text("Nearest Stop")
                                Text(
                                    verbatim: transitLanguage == .english
                                        ? ": "
                                        : "："
                                )
                                Text(verbatim: stopName)
                                if let nearestJourneyStop,
                                   let code = stopCode(for: nearestJourneyStop) {
                                    Text(verbatim: " (\(code))")
                                }
                            }
                        } else {
                            Text("Nearest Stop")
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(nearestJourneyStop == nil)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        Color(uiColor: .systemBackground)
                            .opacity(0.92)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                Color.accentColor,
                                lineWidth: isNearestETAHighlighted
                                    ? 3
                                    : 0
                            )
                    }
            )
                .animation(
                    accessibilityReduceMotion
                        ? nil
                        : .easeInOut(duration: 0.2),
                    value: isNearestETAHighlighted
                )
            }

            // MARK: - Stops

            Section {

                ForEach(
                    Array(
                        orderedStops.enumerated()
                    ),
                    id: \.element.id
                ) { index, journeyStop in

                    if let stop =
                        journeyStop.stop {

                        let hasTuenMaInterchange =
                            FeederBusInterchange.hasTuenMaBadge(
                                stopID: stop.id,
                                operatorIDs: operatorIds
                            )

                        VStack(alignment: .leading, spacing: 0) {
                            NavigationLink {

                                StopDetailView(
                                    stop: stop,
                                    journey: journey,
                                    journeyStop:
                                        journeyStop
                                )

                            } label: {

                                StopRowView(
                                    journeyStop:
                                        journeyStop,
                                    isFirst:
                                        index == 0,
                                    isLast:
                                        index == orderedStops.count - 1,
                                    stop:
                                        stop,
                                    stopCode: stopCode(for: journeyStop),
                                    boardingFareText:
                                        boardingFareText(
                                            for: journeyStop
                                        ),
                                    operatorIds:
                                        operatorIds,
                                    isHighlighted:
                                        journeyStop.id ==
                                            nearestJourneyStop?.id &&
                                            !isMoreThanOneKilometerAway,
                                    etaResult:
                                        etaResults[
                                            journeyStop.id
                                        ],
                                    isLoadingETA:
                                        loadingStopIds
                                            .contains(
                                                journeyStop.id
                                            ),
                                    isETAUnavailable:
                                        unavailableStopIds
                                            .contains(
                                                journeyStop.id
                                            ),
                                    didETAFail:
                                        failedStopIds
                                            .contains(
                                                journeyStop.id
                                            )
                                )
                                .task {
                                    try? await Task.sleep(
                                        for: .milliseconds(350)
                                    )
                                    guard !Task.isCancelled else { return }

                                    if journeyStop.stopPickDrop != "1" {
                                        await loadETA(
                                            for: journeyStop
                                        )
                                    }
                                }
                            }
                            .allowsHitTesting(onSelectStop == nil)
                            .overlay {
                                if let onSelectStop {
                                    Button {
                                        onSelectStop(journeyStop)
                                    } label: {
                                        Color.clear
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(
                                        stop.displayName(for: transitLanguage)
                                    )
                                }
                            }
                            if hasTuenMaInterchange {
                                FeederBusInterchangeLink(stopID: stop.id)
                                    .padding(.leading, 44)
                                    .padding(.bottom, 8)
                            }
                        }
                        .background(alignment: .leading) {
                            if hasTuenMaInterchange {
                                JourneyStopLineContinuation(
                                    operatorIds: operatorIds
                                )
                            }
                        }
                        .id(journeyStop.id)
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 16,
                                bottom: 0,
                                trailing: 16
                            )
                        )
                        .listRowSeparator(.hidden)

                    } else {

                        HStack(
                            alignment: .top,
                            spacing: 12
                        ) {

                            CustomStopLineView(
                                sequence:
                                    journeyStop.sequence,
                                isFirst:
                                    index == 0,
                                isLast:
                                    index == orderedStops.count - 1,
                                operatorIds:
                                    operatorIds,
                                isHighlighted:
                                    journeyStop.id ==
                                        nearestJourneyStop?.id &&
                                        !isMoreThanOneKilometerAway
                            )

                            Text(
                                "Stop unavailable"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .padding(
                                .vertical,
                                14
                            )
                        }
                        .id(journeyStop.id)
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 16,
                                bottom: 0,
                                trailing: 16
                            )
                        )
                        .listRowSeparator(.hidden)
                    }
                }

            } header: {

                Text(
                    "Stops: \(orderedStops.count)"
                )
            }
            .listRowBackground(
                Color(uiColor: .systemBackground)
                    .opacity(0.92)
            )
        }
        .scrollContentBackground(.hidden)
        .background {
            CustomOperatorBackgroundView(
                operatorIds: operatorIds
            )
        }
        .contentMargins(
            .top,
            0,
            for: .scrollContent
        )
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let reverseJourney {
                    Button {
                        switchDirection(to: reverseJourney)
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .accessibilityLabel(reverseDirectionAccessibilityLabel)
                }

                if journey.route != nil {
                    Button {
                        showsWatchJourneySetup = true
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel(journeyAlertAccessibilityLabel)
                }
            }
        }
        .sheet(isPresented: $showsWatchJourneySetup) {
            if let route = journey.route {
                WatchJourneySetupView(
                    route: route,
                    journeys: [journey],
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
        }
        .alert(
            "Live Activity Unavailable",
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
            locationManager.requestLocation()
        }
        .task(id: journey.id) {
            reverseJourney = nil

            // Let the navigation transition finish before traversing the
            // SwiftData relationships needed to find the opposite journey.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            reverseJourney = findReverseJourney(for: journey)
        }
        }
    }

    private func operatorIds(for route: RouteEntity) -> Set<String> {
        Set(route.operators.flatMap {
            $0.id.split(separator: "+").map(String.init)
        })
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

    private func switchDirection(to newJourney: JourneyEntity) {
        etaResults = [:]
        loadingStopIds = []
        unavailableStopIds = []
        failedStopIds = []
        isNearestETAHighlighted = false
        didApplyInitialETAHighlight = false
        withAnimation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.25)) {
            selectedJourney = newJourney
        }
        locationManager.requestLocation(force: true)
    }

    private func scrollToNearestStop(
        using scrollProxy: ScrollViewProxy
    ) {
        guard let nearestJourneyStop else {
            return
        }

        if accessibilityReduceMotion {
            scrollProxy.scrollTo(
                nearestJourneyStop.id,
                anchor: .center
            )
        } else {
            withAnimation {
                scrollProxy.scrollTo(
                    nearestJourneyStop.id,
                    anchor: .center
                )
            }
        }
    }

    private func distance(
        from userLocation: CLLocation,
        to journeyStop: JourneyStopEntity
    ) -> CLLocationDistance {
        guard let stop = journeyStop.stop else {
            return .greatestFiniteMagnitude
        }

        return userLocation.distance(
            from: CLLocation(
                latitude: stop.latitude,
                longitude: stop.longitude
            )
        )
    }

    // MARK: - Stop ETA

    @MainActor
    private func loadETA(
        for journeyStop:
            JourneyStopEntity
    ) async {

        let stopId =
            journeyStop.id

        guard
            etaResults[stopId] == nil,
            !unavailableStopIds
                .contains(stopId),
            !failedStopIds
                .contains(stopId),
            !loadingStopIds
                .contains(stopId)
        else {
            return
        }

        loadingStopIds.insert(
            stopId
        )

        defer {

            loadingStopIds.remove(
                stopId
            )
        }

        do {

            let result =
                try await RouteETAResolver()
                    .resolve(
                        journey: journey,
                        journeyStop:
                            journeyStop,
                        modelContext:
                            modelContext
                    )

            if let result {

                etaResults[stopId] =
                    result

            } else {

                unavailableStopIds
                    .insert(stopId)
            }

        } catch {

            failedStopIds.insert(
                stopId
            )
        }
    }

}

private struct JourneyStopLineContinuation: View {
    @ScaledMetric(relativeTo: .caption)
    private var sequenceWidth: CGFloat = 24

    @ScaledMetric(relativeTo: .body)
    private var markerWidth: CGFloat = 16

    let operatorIds: [String]

    var body: some View {
        Rectangle()
            .fill(
                operatorIds.first.map {
                    CustomBadgeView.backgroundColor(for: $0)
                } ?? Color.accentColor
            )
            .frame(width: 3)
            .offset(x: sequenceWidth + 8 + markerWidth / 2 - 1.5)
            .allowsHitTesting(false)
    }
}


// MARK: - Stop Row

private struct StopRowView: View {

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.locale)
    private var locale

    let journeyStop:
        JourneyStopEntity

    let isFirst: Bool

    let isLast: Bool

    let stop:
        StopEntity

    let stopCode: String?

    let boardingFareText: String?

    let operatorIds: [String]

    let isHighlighted: Bool

    let etaResult:
        RouteETAResult?

    let isLoadingETA: Bool

    let isETAUnavailable: Bool

    let didETAFail: Bool

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {

            CustomStopLineView(
                sequence:
                    journeyStop.sequence,
                isFirst: isFirst,
                isLast: isLast,
                operatorIds: operatorIds,
                isHighlighted: isHighlighted
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(stop.displayName(for: transitLanguage))
                        .font(isHighlighted ? .title3 : .body)
                        .fontWeight(isHighlighted ? .bold : .regular)

                    if let stopCode {
                        Text(verbatim: "(\(stopCode))")
                            .font(isHighlighted ? .title3 : .body)
                            .fontWeight(isHighlighted ? .bold : .regular)
                            .foregroundStyle(.secondary)
                    }
                }

                if let boardingFareText {
                    Text(boardingFareText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                if let stopRoleText {
                    Text(stopRoleText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            journeyStop.stopPickDrop == "1"
                                ? Color.secondary
                                : Color.accentColor
                        )
                }
            }
            .padding(
                .vertical,
                14
            )

            Spacer()

            // MARK: ETA

            Group {
                if journeyStop.stopPickDrop == "1" {
                    EmptyView()
                } else if isLoadingETA {
                    ProgressView()
                        .controlSize(.small)

                } else if isETAUnavailable {

                    Text("Unavailable")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                } else if didETAFail {

                    Text("Error")
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )

                } else {

                    TimelineView(
                        .periodic(
                            from: .now,
                            by: 1
                        )
                    ) { context in

                        if let nextArrival =
                            nextArrival(
                                at: context.date
                            ) {

                            Text(
                                etaText(
                                    for: nextArrival,
                                    relativeTo:
                                        context.date
                                )
                            )
                            .font(.subheadline)
                            .fontWeight(
                                isHighlighted
                                ? .bold
                                : .regular
                            )
                            .monospacedDigit()

                        } else if etaResult != nil {

                            Text("No ETA")
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                        }
                    }
                }
            }
            .frame(
                maxHeight: .infinity,
                alignment: .center
            )
        }
    }

    private var stopRoleText: String? {
        switch journeyStop.stopPickDrop {
        case "1":
            switch transitLanguage {
            case .english: "Alighting only"
            case .traditionalChinese: "只供落客"
            case .simplifiedChinese: "只供下客"
            }
        case "2":
            switch transitLanguage {
            case .english: "Boarding only"
            case .traditionalChinese: "只供上客"
            case .simplifiedChinese: "只供上客"
            }
        default:
            nil
        }
    }

    // MARK: - Next Arrival

    private func nextArrival(
        at date: Date
    ) -> Date? {

        etaResult?
            .etaRecords
            .compactMap {
                $0.estimatedArrival
            }
            .filter {
                $0 >= date
            }
            .min()
    }

    // MARK: - ETA Text

    private func etaText(
        for arrival: Date,
        relativeTo date: Date
    ) -> String {

        let seconds =
            max(
                0,
                Int(
                    arrival
                        .timeIntervalSince(
                            date
                        )
                )
            )

        let minutes =
            seconds / 60

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
}
