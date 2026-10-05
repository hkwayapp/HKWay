import SwiftUI

struct MTRStopListReturnKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

struct MTRNavigationDepthKey: EnvironmentKey {
    static let defaultValue: () -> Int = { 0 }
}

struct MTRPopToNavigationDepthKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

extension EnvironmentValues {
    var mtrReturnToStopList: (() -> Void)? {
        get { self[MTRStopListReturnKey.self] }
        set { self[MTRStopListReturnKey.self] = newValue }
    }


    var mtrNavigationDepth: () -> Int {
        get { self[MTRNavigationDepthKey.self] }
        set { self[MTRNavigationDepthKey.self] = newValue }
    }

    var mtrPopToNavigationDepth: (Int) -> Void {
        get { self[MTRPopToNavigationDepthKey.self] }
        set { self[MTRPopToNavigationDepthKey.self] = newValue }
    }
}

struct MTRLine: Identifiable, Hashable {
    let id: String
    let title: String
    let rgb: UInt32
    var color: Color {
        Color(red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }
    // App-authored colour approximations, not copied logos or map assets.
    static let all: [Self] = [
        .init(id: "TWL", title: "Tsuen Wan Line", rgb: 0xE2231A),
        .init(id: "KTL", title: "Kwun Tong Line", rgb: 0x00AB4E),
        .init(id: "ISL", title: "Island Line", rgb: 0x0075C2),
        .init(id: "SIL", title: "South Island Line", rgb: 0xB5BD00),
        .init(id: "TKL", title: "Tseung Kwan O Line", rgb: 0x6B208B),
        .init(id: "TCL", title: "Tung Chung Line", rgb: 0xF7943E),
        .init(id: "AEL", title: "Airport Express", rgb: 0x00888A),
        .init(id: "DRL", title: "Disneyland Resort Line", rgb: 0xD49AB8),
        .init(id: "EAL", title: "East Rail Line", rgb: 0x5EB6E4),
        .init(id: "TML", title: "Tuen Ma Line", rgb: 0x9A3820)
    ]
}

struct MTRView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Features")
                    .font(.headline).foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                NavigationLink {
                    MTRJourneyPlannerView()
                } label: {
                    CustomInfoCardView(title: "MTR Journey Planner") {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                NavigationLink {
                    MTRStationSearchView()
                } label: {
                    CustomInfoCardView(title: "Find an MTR Station") {
                        Image(systemName: "magnifyingglass")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                }
                Text("MTR Lines")
                    .font(.headline).foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)
                ForEach(MTRLine.all) { line in
                    NavigationLink(value: line) {
                        HStack(spacing: 14) {
                            Circle().fill(line.color).frame(width: 16, height: 16)
                            Text(LocalizedStringKey(line.title))
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .contentShape(Rectangle())
                        .customInfoCardSurface(cornerRadius: 22)
                    }
                    .buttonStyle(.plain)
                }
                MTRDataNotice()
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .navigationTitle("MTR")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MTRLine.self) { line in
            MTRLineStationsView(line: line)
        }
    }
}

struct MTRStationDestination: Hashable {
    let stationID: String
    let patternID: String
}

struct MTRLineStationsView: View {
    let line: MTRLine
    @Environment(\.transitLanguage) private var language
    @Environment(\.mtrNavigationDepth) private var navigationDepth
    @Environment(\.mtrPopToNavigationDepth) private var popToNavigationDepth
    @State private var patterns: [MTRStationPattern] = []
    @State private var stationLines: [String: Set<String>] = [:]
    @State private var interchangeDestinations: [String: [MTRStation]] = [:]
    @State private var selection = ""
    @State private var failed = false
    @State private var stationScrollPosition = ScrollPosition(edge: .top)
    @State private var stopListNavigationDepth: Int?
    private var pattern: MTRStationPattern? {
        patterns.first { $0.id == selection } ?? patterns.first
    }

    var body: some View {
        Group {
            if failed {
                ContentUnavailableView("Unable to Load MTR Stations", systemImage: "tram.fill")
            } else if let pattern {
                ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                        if let first = pattern.stations.first, let last = pattern.stations.last {
                            lineBanner(origin: first, destination: last)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Direction").font(.headline)
                            if patterns.count > 2 {
                                // Keep all branch endpoints readable rather than squeezing
                                // four long labels into the width of an iPhone.
                                ScrollView(.horizontal, showsIndicators: true) {
                                    directionPicker.fixedSize(horizontal: true, vertical: false)
                                }
                            } else {
                                directionPicker
                            }
                        }
                        Text("Stations").font(.headline).foregroundStyle(.secondary)
                        VStack(spacing: 0) {
                            ForEach(Array(pattern.stations.enumerated()), id: \.element.id) { index, station in
                                NavigationLink(
                                    value: MTRStationDestination(
                                        stationID: station.id,
                                        patternID: pattern.id
                                    )
                                ) {
                                HStack(alignment: .top, spacing: 16) {
                                    CustomStopLineView(sequence: index + 1, isFirst: index == 0,
                                                       isLast: index == pattern.stations.count - 1,
                                                       routeColor: line.color,
                                                       markerAtFirstLine: true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(name(station))
                                        let connections = otherLines(at: station)
                                        let hasExpressRail =
                                            hasExpressRailConnection(
                                                at: station
                                            )
                                        let lightRailRouteIDs =
                                            LightRailStops.routeIDs(
                                                mtrStationCode: station.id
                                            )
                                        if !connections.isEmpty
                                            || hasExpressRail
                                            || lightRailRouteIDs != nil {
                                            VStack(alignment: .leading, spacing: 6) {
                                                if lightRailRouteIDs != nil {
                                                    Text(lightRailInterchangeTitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                } else if hasExpressRail {
                                                    Text(connectingRailwaysTitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                } else {
                                                    Text("Other Lines at This Station")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                ForEach(connections) { connection in
                                                    MTRInterchangeBadge(
                                                        line: connection,
                                                        destinations: destinationNames(
                                                            at: station,
                                                            for: connection
                                                        )
                                                    )
                                                }
                                                if hasExpressRail {
                                                    ExpressRailConnectionBadge()
                                                }
                                                if let lightRailRouteIDs {
                                                    LightRailConnectionBadge(
                                                        routeIDs: lightRailRouteIDs
                                                    )
                                                }
                                            }
                                            .padding(.top, 6)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 16)
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .padding(.top, 21)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .customInfoCardSurface(cornerRadius: 22)
                        Text("Tap a station for live arrivals and platforms. Trains may have different destinations; check before boarding.")
                            .font(.footnote).foregroundStyle(.secondary)
                        MTRDataNotice()
                        }
                        .padding(16)
                    }
                .scrollPosition($stationScrollPosition)
            } else {
                ProgressView("Loading MTR Stations…")
            }
        }
        .foregroundStyle(.primary)
        .background(line.color.opacity(0.10).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey(line.title))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MTRStationDestination.self) { destination in
            if let station = station(withID: destination.stationID) {
                MTRStationETAView(
                    line: line,
                    station: station,
                    patterns: patterns,
                    patternID: destination.patternID
                )
            } else {
                ContentUnavailableView(
                    "Unable to Load MTR Stations",
                    systemImage: "tram.fill"
                )
            }
        }
        .environment(\.mtrReturnToStopList) {
            guard let stopListNavigationDepth else { return }
            popToNavigationDepth(stopListNavigationDepth)
        }
        .onAppear {
            // Keep the original list depth across ETA pushes so the shortcut
            // always unwinds the complete chain of previous/next stations.
            if stopListNavigationDepth == nil {
                stopListNavigationDepth = navigationDepth()
            }
        }
        .task(id: line.id) {
            do {
                patterns = try MTRStations.load(line: line.id)
                stationLines = try MTRStations.loadStationLines()
                interchangeDestinations = try loadInterchangeDestinations()
                selection = patterns.first?.id ?? ""
            } catch { failed = true }
        }
    }

    private func name(_ station: MTRStation) -> String {
        switch language {
        case .english: station.english
        case .traditionalChinese: station.traditional
        case .simplifiedChinese: station.simplified
        }
    }

    private func station(withID id: String) -> MTRStation? {
        patterns.lazy.flatMap(\.stations).first { $0.id == id }
    }

    private func lineBanner(origin: MTRStation, destination: MTRStation) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                MTRLineBadge(line: line).fixedSize(horizontal: true, vertical: false)
                termini(origin: origin, destination: destination)
            }
            VStack(alignment: .leading, spacing: 12) {
                MTRLineBadge(line: line)
                termini(origin: origin, destination: destination)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .customInfoCardSurface()
    }

    private var directionPicker: some View {
        Picker("Direction", selection: $selection) {
            ForEach(patterns) { option in
                Text(patterns.count > 2
                     ? "\(option.stations.first.map(name) ?? "") → \(option.stations.last.map(name) ?? "")"
                     : option.stations.last.map(name) ?? option.id)
                    .tag(option.id)
            }
        }
        .pickerStyle(.segmented)
        .tint(.primary)
    }

    private func termini(origin: MTRStation, destination: MTRStation) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name(origin))
            Text(name(destination))
        }
        .font(.headline.bold())
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func otherLines(at station: MTRStation) -> [MTRLine] {
        let codes = stationLines[station.id] ?? []
        return MTRLine.all.filter { $0.id != line.id && codes.contains($0.id) }
    }

    private func destinationNames(
        at station: MTRStation,
        for connection: MTRLine
    ) -> [String] {
        interchangeDestinations[
            interchangeKey(stationID: station.id, lineID: connection.id)
        ]?.map(name) ?? []
    }

    private func loadInterchangeDestinations() throws -> [String: [MTRStation]] {
        var result: [String: [MTRStation]] = [:]

        for connection in MTRLine.all where connection.id != line.id {
            let connectionPatterns = try MTRStations.load(line: connection.id)

            for pattern in connectionPatterns {
                for station in pattern.stations {
                    guard stationLines[station.id]?.contains(connection.id) == true else {
                        continue
                    }

                    let key = interchangeKey(
                        stationID: station.id,
                        lineID: connection.id
                    )

                    for terminus in [pattern.stations.first, pattern.stations.last]
                        .compactMap({ $0 })
                        where terminus.id != station.id
                    {
                        if result[key]?.contains(where: { $0.id == terminus.id }) != true {
                            result[key, default: []].append(terminus)
                        }
                    }
                }
            }
        }

        return result
    }

    private func interchangeKey(stationID: String, lineID: String) -> String {
        "\(stationID)|\(lineID)"
    }

    private func hasExpressRailConnection(
        at station: MTRStation
    ) -> Bool {
        line.id == "TML" && station.id == "AUS"
    }

    private var connectingRailwaysTitle: String {
        switch language {
        case .english: "Connecting Railways"
        case .traditionalChinese: "接駁鐵路"
        case .simplifiedChinese: "接驳铁路"
        }
    }

    private var lightRailInterchangeTitle: String {
        switch language {
        case .english: "Light Rail Interchange"
        case .traditionalChinese: "輕鐵轉乘"
        case .simplifiedChinese: "轻铁换乘"
        }
    }
}

private struct LightRailConnectionBadge: View {
    let routeIDs: [String]
    @Environment(\.transitLanguage) private var language

    private var title: String {
        switch language {
        case .english: "Light Rail"
        case .traditionalChinese: "輕鐵"
        case .simplifiedChinese: "轻铁"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "tram.fill")
                .font(.caption.weight(.semibold))
            Text("\(title)  \(routeIDs.joined(separator: " · "))")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExpressRailConnectionBadge: View {
    @Environment(\.transitLanguage) private var language

    private var title: String {
        switch language {
        case .english: "Express Rail Link"
        case .traditionalChinese: "高速鐵路"
        case .simplifiedChinese: "高速铁路"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "train.side.front.car")
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.indigo.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.indigo.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MTRInterchangeBadge: View {
    let line: MTRLine
    var destinations: [String] = []

    @Environment(\.transitLanguage) private var language

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(line.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(line.title))
                    .font(.subheadline.weight(.semibold))

                if !destinations.isEmpty {
                    Text(towardsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(line.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(line.color.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var towardsText: String {
        switch language {
        case .english:
            "Towards \(destinations.joined(separator: " / "))"
        case .traditionalChinese:
            "往\(destinations.joined(separator: "／"))"
        case .simplifiedChinese:
            "往\(destinations.joined(separator: "／"))"
        }
    }
}

private struct MTRDataNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Station data: MTR Corporation Limited via DATA.GOV.HK. Data intellectual property belongs to MTR Corporation Limited. Independent app, not affiliated with MTR or the Government.")
                .font(.caption).foregroundStyle(.secondary)
            Link("MTR Open Data", destination: URL(string: "https://data.gov.hk/en-data/dataset/mtr-data-routes-fares-barrier-free-facilities")!)
                .font(.footnote).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
