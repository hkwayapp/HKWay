import SwiftUI

struct MTRStationETAView: View {
    let line: MTRLine
    let station: MTRStation
    let patterns: [MTRStationPattern]
    @State private var direction: MTRTravelDirection
    @State private var patternID: String
    @Environment(\.transitLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.mtrReturnToStopList) private var returnToStopList
    @Environment(PurchaseManager.self) private var purchaseManager
    @State private var response: MTRETAResponse?
    @State private var isLoading = false
    @State private var failed = false
    @State private var requestID: UUID?
    @AppStorage(MTRFavorite.storageKey) private var favoriteMTRStations = ""
    @State private var showsFavoriteMTRLimit = false

    private var currentFavorite: MTRFavorite {
        MTRFavorite(lineID: line.id, stationID: station.id, direction: direction.rawValue)
    }
    private var isFavorite: Bool {
        MTRFavorite.decode(favoriteMTRStations).contains(currentFavorite)
    }

    init(line: MTRLine, station: MTRStation, patterns: [MTRStationPattern], patternID: String) {
        self.line = line
        self.station = station
        self.patterns = patterns
        _direction = State(initialValue: MTRTravelDirection(patternID: patternID))
        _patternID = State(initialValue: patternID)
    }

    private var refreshKey: String {
        scenePhase == .active ? language.rawValue : ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 16) {
                        stationBannerName
                        MTRLineBadge(line: line)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        stationBannerName
                        MTRLineBadge(line: line)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                .customInfoCardSurface()

                Text("Direction").font(.headline)
                ScrollView(.horizontal, showsIndicators: true) {
                    Picker("Direction", selection: $direction) {
                        ForEach(MTRTravelDirection.allCases) { option in
                            Text(directionTitle(option)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented).fixedSize(horizontal: true, vertical: false)
                }
                Text("All reported destinations in this direction are shown. Check each train’s destination before boarding.")
                    .font(.footnote).foregroundStyle(.secondary)

                if isLoading || (response == nil && !failed) {
                    ProgressView("Refreshing MTR Arrivals…").frame(maxWidth: .infinity)
                }
                if failed {
                    Label("Unable to refresh arrivals. Check your connection and retry.", systemImage: "wifi.exclamationmark")
                }
                if let response {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        arrivals(response, now: context.date)
                    }
                }
                adjacentStops
                MTRFareView(boardingStation: station, airportExpress: line.id == "AEL")
                VStack(alignment: .leading, spacing: 10) {
                    Label("Notes", systemImage: "info.circle").font(.headline)
                    Text("MTR live data via DATA.GOV.HK. Data intellectual property belongs to MTR Corporation Limited. Times may change; check platform displays. Independent app, not affiliated with MTR or the Government.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("MTR Live Arrival Open Data", destination: URL(string: "https://data.gov.hk/en-data/dataset/mtr-data2-nexttrain-data")!)
                        .font(.footnote).foregroundStyle(.primary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .customInfoCardSurface(cornerRadius: 22)
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(line.color.opacity(0.10).ignoresSafeArea())
        .environment(\.timeZone, TimeZone(identifier: "Asia/Hong_Kong")!)
        .navigationTitle(name(station)).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let returnToStopList {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: returnToStopList) {
                        Label("Stop List", systemImage: "list.bullet")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                }
                .tint(.primary)
                .accessibilityLabel(Text(LocalizedStringKey(isFavorite ? "Remove from Favorites" : "Add to Favorites")))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh ETA").disabled(isLoading)
            }
        }
        .alert(
            "Favorite MTR Stop Limit Reached",
            isPresented: $showsFavoriteMTRLimit
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Free allows up to 5 favorite MTR station-direction records. Remove one before adding another, or upgrade to Full for unlimited favorites.")
        }
        .refreshable { await refresh() }
        .onChange(of: direction) { _, newDirection in
            if let matchingPattern = patterns.first(where: {
                MTRTravelDirection(patternID: $0.id) == newDirection
                    && $0.stations.contains(where: { $0.id == station.id })
            }) {
                patternID = matchingPattern.id
            }
        }
        .onDisappear {
            requestID = nil
            isLoading = false
        }
        .task(id: refreshKey) {
            guard !refreshKey.isEmpty else { return }
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
            }
        }
    }

    private func toggleFavorite() {
        if isFavorite {
            favoriteMTRStations = MTRFavorite.removing(
                currentFavorite,
                from: favoriteMTRStations
            )
            return
        }

        let policy = AppAccessPolicy(tier: purchaseManager.accessTier)
        guard policy.allowsAddition(
            to: .favoriteMTRStops,
            existingCount: MTRFavorite.decode(favoriteMTRStations).count,
            isAlreadySaved: false
        ) else {
            showsFavoriteMTRLimit = true
            return
        }

        favoriteMTRStations = MTRFavorite.toggling(
            currentFavorite,
            in: favoriteMTRStations
        )
    }

    private var stationBannerName: some View {
        Text(name(station))
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var adjacentStops: some View {
        let neighbors = adjacentStations
        if neighbors.previous != nil || neighbors.next != nil {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                if let previous = neighbors.previous {
                    adjacentStopLink(previous, title: "Previous Stop", icon: "chevron.left")
                }
                if let next = neighbors.next {
                    adjacentStopLink(next, title: "Next Stop", icon: "chevron.right")
                }
            }
        }
    }

    private func adjacentStopLink(
        _ adjacentStation: MTRStation,
        title: LocalizedStringKey,
        icon: String
    ) -> some View {
        NavigationLink {
            MTRStationETAView(
                line: line,
                station: adjacentStation,
                patterns: patterns,
                patternID: activePattern?.id ?? patternID
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(name(adjacentStation))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .customInfoCardSurface(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }

    private var activePattern: MTRStationPattern? {
        if let selected = patterns.first(where: {
            $0.id == patternID
                && MTRTravelDirection(patternID: $0.id) == direction
                && $0.stations.contains(where: { $0.id == station.id })
        }) {
            return selected
        }
        return patterns.first {
            MTRTravelDirection(patternID: $0.id) == direction
                && $0.stations.contains(where: { $0.id == station.id })
        }
    }

    private var adjacentStations: (previous: MTRStation?, next: MTRStation?) {
        guard
            let stations = activePattern?.stations,
            let index = stations.firstIndex(where: { $0.id == station.id })
        else {
            return (nil, nil)
        }
        let previous = index > stations.startIndex ? stations[index - 1] : nil
        let next = index + 1 < stations.endIndex ? stations[index + 1] : nil
        return (previous, next)
    }

    @ViewBuilder private func arrivals(_ response: MTRETAResponse, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if response.status != 1 {
                Label("MTR arrival information is temporarily unavailable.", systemImage: "exclamationmark.triangle")
                if let message = response.message, !message.isEmpty {
                    Text(localizeMessage(message)).font(.callout)
                }
                if let url = response.serviceNoticeURL {
                    Link("Official Service Notice", destination: url).foregroundStyle(.primary)
                }
            } else if let stationData = response.station(line: line.id, code: station.id) {
                if response.isdelay == "Y" {
                    Label("MTR reports delays. Predictions may change.", systemImage: "exclamationmark.triangle")
                }
                let trains = stationData.trains(direction: direction, now: now)
                if trains.isEmpty {
                    Text("No upcoming trains reported in this direction. Try the other direction or refresh.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(trains.enumerated()), id: \.offset) { _, train in
                    trainRow(train, now: now)
                }
            } else {
                Text("MTR arrival information is temporarily unavailable.").foregroundStyle(.secondary)
            }
            if let date = response.updatedAt(line: line.id, code: station.id) {
                HStack { Text("Last Updated"); Text(date, style: .time) }
                    .font(.caption).foregroundStyle(.secondary)
            }
            if response.status == 1 &&
                (failed || (response.updatedAt(line: line.id, code: station.id).map { now.timeIntervalSince($0) > 90 } ?? true)) {
                Label("These predictions may be outdated. Refresh before travelling.", systemImage: "clock.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func trainRow(_ train: MTRTrainPrediction, now: Date) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack { Text("To"); Text(destinationName(train.dest)) }.font(.headline)
                Text("Platform \(train.platform)").font(.subheadline)
                if train.viaRacecourse { Text("Via Racecourse").font(.caption) }
                if line.id == "EAL", let type = train.timetype, ["A", "D"].contains(type) {
                    Text(LocalizedStringKey(type == "D" ? "Departure" : "Arrival"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                if let date = train.date {
                    let seconds = date.timeIntervalSince(now)
                    if seconds < 60 {
                        Text("Due").font(.title3.bold())
                    } else {
                        Text("\(Int(ceil(seconds / 60))) min").font(.title3.bold())
                    }
                    Text(date, style: .time).font(.subheadline)
                } else {
                    Text("ETA unavailable").font(.callout)
                }
            }
            .monospacedDigit()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    @MainActor private func refresh() async {
        guard !Task.isCancelled, scenePhase == .active else { return }
        // A restarted view task must not skip its first fetch while a cancelled
        // request is still unwinding. Only the newest request may publish state.
        let id = UUID()
        requestID = id
        isLoading = true
        defer {
            if requestID == id {
                requestID = nil
                isLoading = false
            }
        }
        let requestedLanguage = language
        do {
            let value = try await MTRETAService().fetch(line: line.id, station: station.id, chinese: language != .english)
            guard !Task.isCancelled, requestID == id, language == requestedLanguage else { return }
            response = value
            failed = false
        } catch {
            guard !Task.isCancelled, requestID == id, language == requestedLanguage else { return }
            failed = true
        }
    }

    private func directionTitle(_ option: MTRTravelDirection) -> String {
        var seen = Set<String>()
        return patterns.filter { MTRTravelDirection(patternID: $0.id) == option }
            .compactMap { $0.stations.last }
            .filter { seen.insert($0.id).inserted }
            .map(name).joined(separator: " / ")
    }

    private func destination(_ code: String) -> MTRStation? {
        patterns.lazy.flatMap(\.stations).first { $0.id == code }
    }
    private func destinationName(_ code: String) -> String {
        if let station = destination(code) { return name(station) }
        // RAC is documented in the Next Train API but absent from the regular CSV patterns.
        if code == "RAC" {
            return language == .english ? "Racecourse" : language == .traditionalChinese ? "馬場" : "马场"
        }
        return code
    }
    private func name(_ station: MTRStation) -> String {
        switch language {
        case .english: station.english
        case .traditionalChinese: station.traditional
        case .simplifiedChinese: station.simplified
        }
    }
    private func localizeMessage(_ text: String) -> String {
        language == .simplifiedChinese
            ? text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text : text
    }
}
