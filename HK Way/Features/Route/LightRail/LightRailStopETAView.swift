import SwiftUI

struct LightRailStopETAView: View {
    var route: LightRailRoute? = nil
    let stop: LightRailStop
    var destination: LightRailStop? = nil
    var circular: Bool = false
    var fareDestinations: [LightRailStop] = []
    var servedRouteIDs: [String] = []
    @Environment(\.transitLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var response: LightRailETAResponse?
    @State private var isLoading = false
    @State private var refreshFailed = false
    @AppStorage(LightRailStopFavorite.storageKey)
    private var favoriteStopIDsValue = ""
    @State private var showsFavoriteLimit = false

    private var favoriteStopIDs: Set<Int> {
        LightRailStopFavorite.ids(from: favoriteStopIDsValue)
    }

    private var isFavorite: Bool {
        favoriteStopIDs.contains(stop.stationID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let route {
                    CustomRouteDetailedBanner(
                    routeNumber: route.id,
                    origin: name(stop),
                    destination: circular ? route.title(for: language) : destination.map(name) ?? route.title(for: language),
                    routeBadgeColor: route.color,
                    routeBadgeTextColor: route.usesDarkText ? .black : .white
                )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(name(stop)).font(.title2.bold())
                        Text("All Routes at This Stop").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], alignment: .leading, spacing: 8) {
                            ForEach(servedRouteIDs, id: \.self) { number in
                                LightRailRouteBadge(number: number)
                            }
                        }
                        Text("Regular routes serving this stop. Upcoming trains are grouped by platform below.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .customInfoCardSurface(cornerRadius: 22)
                }

                if isLoading {
                    ProgressView("Refreshing Light Rail Arrivals…")
                        .frame(maxWidth: .infinity)
                }

                if refreshFailed {
                    Label("Unable to refresh arrivals. Check your connection and retry.", systemImage: "wifi.exclamationmark")
                        .font(.callout)
                }

                if let response {
                    if response.status != 1 {
                        Label("Light Rail arrival information is temporarily unavailable.", systemImage: "exclamationmark.triangle")
                    } else {
                        // A stop-detail page should describe the whole stop, not
                        // hide trains on the opposite or adjacent platforms.
                        let platforms = response.allRoutePlatforms
                        if platforms.isEmpty {
                            Text(LocalizedStringKey(route == nil
                                ? "No upcoming trains reported at this stop."
                                : "No upcoming trains reported for this route and direction."))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(platforms) { platform in
                            VStack(alignment: .leading, spacing: 12) {
                                let trains = platform.route_list ?? []
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Platform \(platform.platform_id)")
                                        .font(.headline)
                                    if let direction = platformDirection(
                                        trains
                                    ) {
                                        Text(verbatim: direction)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                ForEach(trains.indices, id: \.self) { index in
                                    if index > 0 { Divider() }
                                    trainRow(trains[index])
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .customInfoCardSurface(cornerRadius: 22)
                        }
                    }

                    if let timestamp = response.timestamp {
                        HStack {
                            Text("Last Updated")
                            Text(timestamp, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if refreshFailed || isStale(response) {
                        Label("These predictions may be outdated. Refresh before travelling.", systemImage: "clock.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if route != nil {
                    LightRailFareView(boardingStop: stop, destinations: fareDestinations)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Notes", systemImage: "info.circle")
                        .font(.headline)
                    if route != nil {
                        Text("Standard adult fares before discounts or concessions. Fare destination does not change the train direction shown above.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Divider()
                    }
                    Text("Arrival information provided by MTR. Times may change; check the platform display.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if route != nil {
                        Link("Official Light Rail Fares", destination: URL(string: "https://opendata.mtr.com.hk/data/light_rail_fares.csv")!)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .customInfoCardSurface(cornerRadius: 22)
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background((route?.color ?? Color.orange).opacity(0.10).ignoresSafeArea())
        .navigationTitle(name(stop))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(
                    isFavorite ? "Remove from Favorites" : "Add to Favorites"
                )

                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh ETA")
                .disabled(isLoading)
            }
        }
        .alert(
            favoriteLimitTitle,
            isPresented: $showsFavoriteLimit
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(favoriteLimitMessage)
        }
        .refreshable { await refresh() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
            }
        }
    }

    private func toggleFavorite() {
        let ids = favoriteStopIDs
        if ids.contains(stop.stationID) {
            favoriteStopIDsValue = LightRailStopFavorite.toggling(
                stop.stationID,
                in: favoriteStopIDsValue
            )
            return
        }

        let policy = AppAccessPolicy(tier: purchaseManager.accessTier)
        guard policy.allowsAddition(
            to: .favoriteLightRailStops,
            existingCount: ids.count,
            isAlreadySaved: false
        ) else {
            showsFavoriteLimit = true
            return
        }

        favoriteStopIDsValue = LightRailStopFavorite.toggling(
            stop.stationID,
            in: favoriteStopIDsValue
        )
    }

    private var favoriteLimitTitle: String {
        switch language {
        case .english: "Favorite Light Rail Stop Limit Reached"
        case .traditionalChinese: "已達輕鐵車站收藏上限"
        case .simplifiedChinese: "已达轻铁车站收藏上限"
        }
    }

    private var favoriteLimitMessage: String {
        switch language {
        case .english:
            "Free allows up to 5 favorite Light Rail stops. Remove one before adding another, or upgrade to Full for unlimited favorites."
        case .traditionalChinese:
            "免費版最多可收藏 5 個輕鐵車站。請先移除一個，或升級至完全版以無限收藏。"
        case .simplifiedChinese:
            "免费版最多可收藏 5 个轻铁车站。请先移除一个，或升级至完全版以无限收藏。"
        }
    }

    private func trainRow(_ train: LightRailETATrain) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if route == nil || train.route_no != route?.id {
                LightRailRouteBadge(number: train.route_no)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(localized(english: train.dest_en, chinese: train.dest_ch)).font(.headline)
                Text(LocalizedStringKey(train.arrival_departure == "D" ? "Departure" : "Arrival"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if train.stop == 1 {
                Text("Service Suspended").font(.headline)
            } else {
                Text(localized(english: train.time_en ?? "—", chinese: train.time_ch ?? train.time_en ?? "—"))
                    .font(.title3.bold())
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func platformDirection(
        _ trains: [LightRailETATrain]
    ) -> String? {
        var seen = Set<String>()
        let destinations = trains.compactMap { train -> String? in
            let destination = localized(
                english: train.dest_en,
                chinese: train.dest_ch
            )
            guard !destination.isEmpty,
                  seen.insert(destination).inserted else {
                return nil
            }
            return destination
        }
        guard !destinations.isEmpty else { return nil }
        let prefix = language == .english ? "To " : "往"
        return prefix + destinations.joined(separator: " / ")
    }

    @MainActor private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await LightRailETAService().fetch(stationID: stop.stationID)
            guard !Task.isCancelled else { return }
            response = result
            refreshFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            refreshFailed = true
        }
    }

    private func isStale(_ response: LightRailETAResponse) -> Bool {
        guard let date = response.timestamp else { return true }
        return Date().timeIntervalSince(date) > 90
    }

    private func name(_ stop: LightRailStop) -> String {
        localized(english: stop.english, chinese: stop.traditional)
    }

    private func localized(english: String, chinese: String) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: chinese
        case .simplifiedChinese:
            chinese.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? chinese
        }
    }
}
