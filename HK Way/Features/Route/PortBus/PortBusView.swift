import SwiftUI
import SwiftData

struct PortBusView: View {
    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.dynamicTypeSize)
    private var typeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12),
              count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose a Boundary or Connection")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PortBoundaryControlPoint.allCases) { port in
                        NavigationLink {
                            if port == .shaTauKok || port == .huanggang {
                                PortServiceInformationView(port: port)
                            } else {
                                PortBusRouteListView(port: port)
                            }
                        } label: {
                            CustomInfoCardView(title: "") {
                                VStack(spacing: 8) {
                                    Image(systemName: port.systemImage)
                                        .font(.title2)
                                        .accessibilityHidden(true)

                                    Text(port.title(for: transitLanguage))
                                        .font(.headline)
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Label(
                    "Public bus and green minibus routes within Hong Kong are shown here. Cross-boundary coaches and port shuttle buses are separate services.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Port Bus")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PortBusRouteListView: View {
    let port: PortBoundaryControlPoint

    private enum HZMBRouteGroup: String, CaseIterable, Identifiable {
        case airport
        case boundaryAndMinibus

        var id: Self { self }
    }

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    @State private var hzmbRouteGroup: HZMBRouteGroup = .airport

    private var allMatchingRoutes: [RouteEntity] {
        routes
            .filter { port.matches(route: $0) }
            .sorted { lhs, rhs in
                let numberComparison = lhs.number
                    .localizedStandardCompare(rhs.number)

                if numberComparison != .orderedSame {
                    return numberComparison == .orderedAscending
                }

                return lhs.displayDestination(for: transitLanguage)
                    .localizedStandardCompare(
                        rhs.displayDestination(for: transitLanguage)
                    ) == .orderedAscending
            }
    }

    private var matchingRoutes: [RouteEntity] {
        guard port == .hzmb else { return allMatchingRoutes }
        return allMatchingRoutes.filter { route in
            let isAirportRoute = route.number.uppercased().hasPrefix("A")
            switch hzmbRouteGroup {
            case .airport: return isAirportRoute
            case .boundaryAndMinibus: return !isAirportRoute
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if port == .hzmb {
                Picker(hzmbPickerTitle, selection: $hzmbRouteGroup) {
                    ForEach(HZMBRouteGroup.allCases) { group in
                        Text(hzmbGroupTitle(group)).tag(group)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Group {
                if matchingRoutes.isEmpty {
                    ContentUnavailableView(
                        "No Port Routes",
                        systemImage: port.systemImage,
                        description: Text("Update the dataset and try again.")
                    )
                } else {
                    List(matchingRoutes) { route in
                        NavigationLink {
                            RouteDetailView(route: route)
                        } label: {
                            RouteRowView(
                                route: route,
                                etaResult: nil,
                                isCompact: true,
                                allowsTwoLineOrigin: true,
                                allowsTwoLineDestination: true,
                                allowsFullNameWrapping: true,
                                usesUniformNameStyle: true
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(port.title(for: transitLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hzmbPickerTitle: String {
        switch transitLanguage {
        case .english: "HZMB Route Type"
        case .traditionalChinese: "港珠澳大橋路線類別"
        case .simplifiedChinese: "港珠澳大桥路线类别"
        }
    }

    private func hzmbGroupTitle(_ group: HZMBRouteGroup) -> String {
        switch (group, transitLanguage) {
        case (.airport, .english): "A Routes"
        case (.airport, .traditionalChinese): "A 線"
        case (.airport, .simplifiedChinese): "A 线"
        case (.boundaryAndMinibus, .english): "B / Minibus"
        case (.boundaryAndMinibus, .traditionalChinese): "B 線／小巴"
        case (.boundaryAndMinibus, .simplifiedChinese): "B 线／小巴"
        }
    }
}

enum PortBoundaryControlPoint: String, CaseIterable, Identifiable {
    case hzmb
    case shenzhenBay
    case heungYuenWai
    case lokMaChauSpurLine
    case sheungShui
    case shaTauKok
    case huanggang

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .hzmb: "road.lanes"
        case .shenzhenBay: "water.waves"
        case .heungYuenWai: "building.2"
        case .lokMaChauSpurLine: "tram.fill"
        case .sheungShui: "bus.fill"
        case .shaTauKok: "building.2"
        case .huanggang: "bus.doubledecker.fill"
        }
    }

    func title(for language: TransitLanguage) -> String {
        switch self {
        case .hzmb:
            language.localized("HZMB Hong Kong Port")
        case .shenzhenBay:
            language.localized("Shenzhen Bay Port")
        case .heungYuenWai:
            language.localized("Heung Yuen Wai Control Point")
        case .lokMaChauSpurLine:
            language.localized("Lok Ma Chau Spur Line Control Point")
        case .sheungShui:
            language.localized("Sheung Shui Connections")
        case .shaTauKok:
            language.localized("Sha Tau Kok Control Point")
        case .huanggang:
            language.localized("Huanggang / Lok Ma Chau")
        }
    }

    /// Uses the same verified stop-name mapping as the Port Bus screens so
    /// other transport features can select an actual local control-point stop.
    func matches(stop: StopEntity) -> Bool {
        stopNameFragments.contains { fragment in
            stop.nameEnglish.localizedCaseInsensitiveContains(fragment)
        }
    }

    fileprivate func matches(route: RouteEntity) -> Bool {
        if self == .sheungShui {
            let ports: [Self] = [.hzmb, .shenzhenBay, .heungYuenWai, .lokMaChauSpurLine]
            return ports.contains { $0.matches(route: route) } && route.journeys.contains { journey in
                journey.journeyStops.contains {
                    $0.stop?.nameEnglish.localizedCaseInsensitiveContains("Sheung Shui") == true
                }
            }
        }
        let normalizedRouteNumber = route.number.uppercased()
        let isHZMBAirportRoute = self == .hzmb
            && normalizedRouteNumber.hasPrefix("A")

        guard routeNumbers.contains(normalizedRouteNumber)
                || isHZMBAirportRoute else {
            return false
        }

        return route.journeys.contains { journey in
            journey.journeyStops.contains { journeyStop in
                guard let stop = journeyStop.stop else {
                    return false
                }

                return stopNameFragments.contains { fragment in
                    stop.nameEnglish.localizedCaseInsensitiveContains(
                        fragment
                    )
                }
            }
        }
    }

    private var routeNumbers: Set<String> {
        switch self {
        case .hzmb:
            ["B4", "B5", "B6", "B6S", "901"]
        case .shenzhenBay:
            ["B2", "B2P", "B3", "B3A", "B3X", "618", "618A", "618B"]
        case .heungYuenWai:
            ["B7", "B8", "B9", "59S"]
        case .lokMaChauSpurLine:
            ["B1", "75"]
        case .sheungShui, .shaTauKok, .huanggang:
            []
        }
    }

    private var stopNameFragments: [String] {
        switch self {
        case .hzmb:
            ["HZMB Hong Kong Port", "Hong Kong-Zhuhai-Macao Bridge"]
        case .shenzhenBay:
            ["Shenzhen Bay Port"]
        case .heungYuenWai:
            ["Heung Yuen Wai", "Hueng Yuen Wai"]
        case .lokMaChauSpurLine:
            ["Lok Ma Chau Spur Line", "Lok Ma Chau Station"]
        case .sheungShui, .shaTauKok, .huanggang:
            []
        }
    }
}

private struct PortServiceInformationView: View {
    let port: PortBoundaryControlPoint
    @Environment(\.transitLanguage) private var language

    private var isShaTauKok: Bool { port == .shaTauKok }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(LocalizedStringKey(isShaTauKok ? "Clearance Suspended" : "Separate Shuttle and Coach Services"),
                      systemImage: isShaTauKok ? "exclamationmark.triangle" : "info.circle")
                    .font(.headline)
                Text(LocalizedStringKey(isShaTauKok
                     ? "The official page lists Sha Tau Kok clearance services as suspended. Check the latest arrangements before travelling."
                     : "Huanggang is served via Lok Ma Chau by separate cross-boundary shuttle and coach services, not Lok Ma Chau Spur Line station. These services are not included in the current local-bus dataset."))
                if !isShaTauKok {
                    Text("Shuttle and coach route support is planned. Live arrivals are not available here.")
                        .foregroundStyle(.secondary)
                }
                Text("Status checked: 2026-08-31. Arrangements may change.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Official Boundary Transport Information", destination: URL(string:
                    "https://www.td.gov.hk/en/transport_in_hong_kong/land_based_cross_boundary_transport/" +
                    (isShaTauKok ? "access_to_sha_tau_kok_control_point/" : "access_to_lok_ma_chau_control_point/"))!)
                    .foregroundStyle(.primary)
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .customInfoCardSurface(cornerRadius: 22)
            .padding()
        }
        .navigationTitle(port.title(for: language))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PortBusView()
    }
}
