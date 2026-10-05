import SwiftUI

struct MTRJourneyPlannerView: View {
    private let viaTungChung: Bool
    private let promptsForOrigin: Bool

    init(viaTungChung: Bool = false, destinationStationID: String? = nil) {
        self.viaTungChung = viaTungChung
        self.promptsForOrigin = viaTungChung || destinationStationID != nil
        _destinationID = State(initialValue: viaTungChung ? "TUC" : destinationStationID ?? "")
    }

    private enum Endpoint: String, Identifiable { case origin, destination; var id: String { rawValue } }
    @Environment(\.transitLanguage) private var language
    @Environment(\.mtrNavigationDepth) private var navigationDepth
    @Environment(\.mtrPopToNavigationDepth) private var popToNavigationDepth
    @State private var planner: MTRJourneyPlanner?
    @State private var failed = false
    @State private var originID = ""
    @State private var destinationID = ""
    @State private var selecting: Endpoint?
    @State private var journey: MTRPlannedJourney?
    @State private var planning = false
    @State private var fares: [String: MTRAdultFare] = [:]
    @State private var fareStations: [MTRFareStation] = []
    @State private var journeyListNavigationDepth: Int?

    private var origin: MTRStation? { planner?.stations.first { $0.id == originID } }
    private var destination: MTRStation? { planner?.stations.first { $0.id == destinationID } }
    private var planKey: String { "\(planner != nil)|\(originID)|\(destinationID)" }
    private var fare: MTRAdultFare? {
        guard let from = fareStations.first(where: { $0.id == originID }),
              let to = fareStations.first(where: { $0.id == destinationID }) else { return nil }
        return fares[MTRFares.key(from: from.fareID, to: to.fareID)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if failed {
                    ContentUnavailableView("Unable to Load MTR Stations", systemImage: "tram.fill")
                } else if let planner {
                    if promptsForOrigin && origin == nil {
                        Text("Where are you starting from?").font(.headline)
                    }
                    VStack(spacing: 12) {
                        endpointButton(.origin, station: origin)
                        Button {
                            let previous = originID
                            originID = destinationID
                            destinationID = previous
                        } label: { Label("Swap Stations", systemImage: "arrow.up.arrow.down") }
                            .buttonStyle(.plain).frame(minHeight: 44)
                            .disabled(originID.isEmpty && destinationID.isEmpty)
                        endpointButton(.destination, station: destination)
                    }
                    if viaTungChung && destinationID == "TUC" {
                        Text("This planner covers the MTR journey to Tung Chung only. Check the official visitor and operator websites for onward travel; onward fares are not included.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Fewest train changes, then fewest stops. Not a fastest-route estimate.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if origin == nil || destination == nil {
                        Text("Choose two stations to plan your MTR journey.")
                    } else if originID == destinationID {
                        Text("Origin and destination are the same station.")
                    } else if planning {
                        ProgressView("Planning MTR Journey…").frame(maxWidth: .infinity)
                    } else if let journey {
                        HStack(spacing: 12) {
                            CustomInfoCardView(title: "Train Changes") {
                                Text(journey.changes, format: .number).font(.title2.bold())
                            }
                            CustomInfoCardView(title: "Stops") {
                                Text(journey.stops, format: .number).font(.title2.bold())
                            }
                        }
                        ForEach(Array(journey.legs.enumerated()), id: \.offset) { index, leg in
                            if index > 0, let interchange = leg.stations.first {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Change Trains At", systemImage: "arrow.triangle.branch")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    stationName(interchange)
                                }.padding(.horizontal, 8)
                            }
                            legCard(leg, planner: planner)
                        }
                        Text("Adult Fares").font(.headline)
                        if let fare {
                            HStack(spacing: 12) {
                                CustomInfoCardView(title: "Adult Octopus") {
                                    Text(price(fare.octopus)).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                CustomInfoCardView(title: "Adult Single Journey") {
                                    Text(price(fare.singleJourney)).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.7)
                                }
                            }
                        } else {
                            Text("Fare unavailable for this journey.").foregroundStyle(.secondary)
                        }
                        Text("Published origin-to-destination adult fare, not a sum of individual legs. Excludes First Class, concessions and promotions.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Fare data retrieved: 2026-08-31. Prices may change.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("No Supported MTR Journey", systemImage: "tram.fill")
                    }
                    notes
                } else {
                    ProgressView("Loading MTR Stations…").frame(maxWidth: .infinity)
                }
            }.padding(16)
        }
        .foregroundStyle(.primary)
        .background(Color.gray.opacity(0.08).ignoresSafeArea())
        .navigationTitle("MTR Journey Planner")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.mtrReturnToStopList) {
            guard let journeyListNavigationDepth else { return }
            popToNavigationDepth(journeyListNavigationDepth)
        }
        .onAppear {
            // Record the planner's own position once. Do not replace it when an
            // ETA child disappears, otherwise a later return only pops one page.
            if journeyListNavigationDepth == nil {
                journeyListNavigationDepth = navigationDepth()
            }
        }
        .sheet(item: $selecting) { endpoint in
            MTRJourneyStationPicker(stations: planner?.stations ?? [], patternsByLine: planner?.patternsByLine ?? [:],
                selection: endpoint == .origin ? $originID : $destinationID)
                .environment(\.transitLanguage, language)
                .environment(\.locale, language.locale)
        }
        .task {
            guard planner == nil, !failed else { return }
            do {
                guard let url = Bundle.main.url(forResource: "MTRStations", withExtension: "csv") else {
                    throw MTRStations.DataError.missingFile
                }
                planner = try MTRJourneyPlanner(csv: String(contentsOf: url, encoding: .utf8),
                                               lineIDs: MTRLine.all.map(\.id))
            } catch { failed = true }
            // A missing fare table must not block station-to-station planning.
            fareStations = (try? MTRStations.loadFareStations(airportExpress: false)) ?? []
            fares = (try? MTRFares.load(airportExpress: false)) ?? [:]
            if promptsForOrigin, planner != nil, destination != nil, originID.isEmpty {
                selecting = .origin
            }
        }
        .task(id: planKey) {
            journey = nil
            guard let planner, origin != nil, destination != nil, originID != destinationID else {
                planning = false
                return
            }
            planning = true
            await Task.yield()
            guard !Task.isCancelled else { return }
            journey = planner.plan(from: originID, to: destinationID)
            planning = false
        }
    }

    private func endpointButton(_ endpoint: Endpoint, station: MTRStation?) -> some View {
        Button { selecting = endpoint } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(endpoint == .origin ? "Origin" : "Destination"))
                        .font(.caption).foregroundStyle(.secondary)
                    if let station {
                        stationName(
                            station,
                            showsEnglishSubtitle: false,
                            showsLightRailRoutes: false,
                            prominent: true
                        )
                    }
                    else { Text("Choose MTR Station").font(.headline) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
            .customInfoCardSurface(cornerRadius: 22)
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func legCard(_ leg: MTRJourneyLeg, planner: MTRJourneyPlanner) -> some View {
        if let line = MTRLine.all.first(where: { $0.id == leg.lineID }),
           let boarding = leg.stations.first, let alighting = leg.stations.last,
           let terminus = leg.pattern.stations.last {
            VStack(alignment: .leading, spacing: 12) {
                MTRInterchangeBadge(line: line)
                HStack(alignment: .top) {
                    Text("Train Towards").foregroundStyle(.secondary)
                    Text(name(terminus)).fontWeight(.semibold)
                }.font(.subheadline)
                stationName(boarding)
                Image(systemName: "arrow.down").foregroundStyle(line.color)
                stationName(alighting)
                DisclosureGroup("Stops") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(leg.stations.enumerated()), id: \.offset) { index, station in
                            HStack(alignment: .top, spacing: 10) {
                                Text(index + 1, format: .number).foregroundStyle(.secondary)
                                stationName(station)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }.tint(.primary)
                NavigationLink {
                    MTRStationETAView(line: line, station: boarding,
                        patterns: planner.patternsByLine[line.id] ?? [], patternID: leg.pattern.id)
                } label: {
                    Label("View Boarding Station Arrivals", systemImage: "clock")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .customInfoCardSurface(cornerRadius: 22)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(line.color).frame(width: 4).padding(.vertical, 20)
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "info.circle").font(.headline)
            Text("Regular MTR lines only. Airport Express and walking connections between different station codes are not included.")
            Text("Based on the published station network, not current operating hours or disruptions. Check each train’s destination and service notices before boarding.")
            Text("Station data: MTR Corporation Limited via DATA.GOV.HK. Data intellectual property belongs to MTR Corporation Limited. Independent app, not affiliated with MTR or the Government.")
            Link("MTR Open Data", destination: URL(string: "https://data.gov.hk/en-data/dataset/mtr-data-routes-fares-barrier-free-facilities")!)
                .foregroundStyle(.primary)
        }
        .font(.footnote).foregroundStyle(.secondary)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func stationName(
        _ station: MTRStation,
        showsEnglishSubtitle: Bool = true,
        showsLightRailRoutes: Bool = true,
        prominent: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name(station))
                .font(prominent ? .title3.bold() : .headline)
            if showsEnglishSubtitle, language != .english {
                Text(station.english)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if showsLightRailRoutes,
               let routes = lightRailRoutes(for: station) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "tram.fill")
                    Text("\(lightRailLabel): \(routes.joined(separator: " · "))")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var lightRailLabel: String {
        switch language {
        case .english: "Light Rail"
        case .traditionalChinese: "輕鐵"
        case .simplifiedChinese: "轻铁"
        }
    }

    private func lightRailRoutes(for station: MTRStation) -> [String]? {
        LightRailStops.routeIDs(mtrStationCode: station.id)
    }
    private func name(_ station: MTRStation) -> String {
        switch language {
        case .english: station.english
        case .traditionalChinese: station.traditional
        case .simplifiedChinese: station.simplified
        }
    }
    private func price(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_HK")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "HK$" + (formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "—")
    }
}

private struct MTRJourneyStationPicker: View {
    private enum Filter: Equatable {
        case all, favorites, recent, line(String)
    }
    let stations: [MTRStation]
    let patternsByLine: [String: [MTRStationPattern]]
    @Binding var selection: String
    @Environment(\.transitLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedFilter: Filter = .all
    @AppStorage(MTRStationShortcuts.recentStorageKey) private var recentStationIDs = ""
    @AppStorage(MTRFavorite.storageKey) private var favoriteStations = ""
    private var selectedLine: String? {
        if case let .line(id) = selectedFilter { return id }
        return nil
    }
    private var recentStations: [MTRStation] {
        Array(MTRStationShortcuts.resolve(MTRStationShortcuts.recentIDs(recentStationIDs), stations: stations)
            .prefix(MTRStationShortcuts.recentLimit))
    }
    private var savedStations: [MTRStation] {
        MTRStationShortcuts.favorites(favoriteStations, stations: stations)
    }
    private var groups: [MTRStationFilter.Group] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if selectedFilter == .favorites { return [.init(id: "favorites", stations: savedStations)] }
            if selectedFilter == .recent { return [.init(id: "recent", stations: recentStations)] }
        }
        return MTRStationFilter.groups(stations: stations, patterns: selectedLine.flatMap { patternsByLine[$0] } ?? [], query: query)
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 8) {
                        lineFilter(nil)
                        shortcutFilter(.favorites, title: "Favorites", symbol: "bookmark")
                        shortcutFilter(.recent, title: "Recent", symbol: "clock")
                        ForEach(MTRLine.all.filter { patternsByLine[$0.id] != nil }) { line in
                            lineFilter(line)
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 8)
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Search covers all MTR lines.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                }
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.stations) { station in
                                stationRow(station)
                            }
                        } header: {
                            if group.id == "branches" { Text("Other Branch Stations") }
                            else if group.id == "all" { Text("All Stations") }
                            else if group.id == "favorites" { Text("Favorite Stations") }
                            else if group.id == "recent", !recentStations.isEmpty {
                                HStack {
                                    Text("Recent Stations")
                                    Spacer()
                                    Button("Clear") { recentStationIDs = "" }
                                        .foregroundStyle(.primary)
                                        .accessibilityLabel("Clear Recent Stations")
                                }
                            }
                        }
                    }
                }
                .overlay {
                    if groups.allSatisfy({ $0.stations.isEmpty }) {
                        if selectedFilter == .recent {
                            ContentUnavailableView("No Recent Stations", systemImage: "clock",
                                description: Text("Stations you select will appear here."))
                        } else if selectedFilter == .favorites {
                            ContentUnavailableView("No Favorite MTR Stations", systemImage: "bookmark",
                                description: Text("Choose a direction on an MTR station’s arrivals page, then tap the bookmark to save it."))
                        } else {
                            ContentUnavailableView("No Matching MTR Stations", systemImage: "magnifyingglass")
                        }
                    }
                }
                .id(String(describing: selectedFilter))
            }
            .foregroundStyle(.primary)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search MTR Stations")
            .onChange(of: query) { _, value in
                if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { selectedFilter = .all }
            }
            .navigationTitle("Choose MTR Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(.primary) }
            }
        }
    }

    private func lineFilter(_ line: MTRLine?) -> some View {
        filterChip(line.map { .line($0.id) } ?? .all,
                   title: line?.title ?? "All Lines", color: line?.color, symbol: nil)
    }

    private func shortcutFilter(_ filter: Filter, title: String, symbol: String) -> some View {
        filterChip(filter, title: title, color: nil, symbol: symbol)
    }

    private func filterChip(_ filter: Filter, title: String, color: Color?, symbol: String?) -> some View {
        let selected = selectedFilter == filter
        return Button {
            query = ""
            selectedFilter = filter
        } label: {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 9, height: 9) }
                if let symbol { Image(systemName: symbol) }
                Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold))
                if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background((color ?? Color.gray).opacity(selected ? 0.22 : 0.08), in: Capsule())
            .overlay { Capsule().strokeBorder(selected ? (color ?? Color.primary) : Color.clear, lineWidth: 1.5) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func stationRow(_ station: MTRStation) -> some View {
                Button {
                    recentStationIDs = MTRStationShortcuts.recording(station.id, in: recentStationIDs)
                    selection = station.id
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language == .english ? station.english :
                                 language == .traditionalChinese ? station.traditional : station.simplified)
                            if language != .english { Text(station.english).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if station.id == selection { Image(systemName: "checkmark") }
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
    }
}
