import SwiftUI

struct LightRailView: View {
    @Environment(\.transitLanguage) private var language
    @SceneStorage("lightRailBrowseShowsStops") private var showsStops = false
    @State private var selectedRouteID: String?
    @State private var selectedStop: LightRailStopCatalogueEntry?
    @State private var selectedRouteStop: LightRailRouteStopSelection?

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                NavigationSplitView {
                    browser
                        .navigationTitle("Light Rail (LRT)")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationSplitViewColumnWidth(
                            min: 320,
                            ideal: 360,
                            max: 400
                        )
                } detail: {
                    detail
                }
            } else {
                browser
                    .navigationTitle("Light Rail (LRT)")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var browser: some View {
        VStack(spacing: 0) {
            Picker("Browse Light Rail", selection: $showsStops) {
                Text("Routes").tag(false)
                Text("Stops").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if showsStops {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    LightRailStopBrowser { entry in
                        selectedStop = entry
                    }
                } else {
                    LightRailStopBrowser()
                }
            } else {
                routeList
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if showsStops, let selectedStop {
            NavigationStack {
                LightRailStopETAView(
                    stop: selectedStop.stop,
                    servedRouteIDs: selectedStop.routeIDs
                )
            }
        } else if !showsStops,
                  let selectedRouteStop,
                  let route = LightRailRoute.regularRoutes.first(
                    where: { $0.id == selectedRouteID }
                  ) {
            NavigationStack {
                LightRailStopETAView(
                    route: route,
                    stop: selectedRouteStop.stop,
                    destination: selectedRouteStop.destination,
                    circular: selectedRouteStop.circular,
                    fareDestinations: selectedRouteStop.fareDestinations
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            self.selectedRouteStop = nil
                        } label: {
                            Label("Back to Route", systemImage: "chevron.left")
                        }
                    }
                }
            }
        } else if !showsStops,
                  let route = LightRailRoute.regularRoutes.first(
                    where: { $0.id == selectedRouteID }
                  ) {
            NavigationStack {
                LightRailRouteDetailView(route: route) { selection in
                    selectedRouteStop = selection
                }
            }
        } else {
            ContentUnavailableView(
                selectionTitle,
                systemImage: showsStops
                    ? "tram.fill"
                    : "point.topleft.down.to.point.bottomright.curvepath",
                description: Text(selectionDescription)
            )
        }
    }

    private var selectionTitle: String {
        switch language {
        case .english: showsStops ? "Select a Stop" : "Select a Route"
        case .traditionalChinese: showsStops ? "選擇車站" : "選擇路線"
        case .simplifiedChinese: showsStops ? "选择车站" : "选择路线"
        }
    }

    private var selectionDescription: String {
        switch language {
        case .english:
            showsStops
                ? "Choose a Light Rail stop from the sidebar."
                : "Choose a Light Rail route from the sidebar."
        case .traditionalChinese:
            showsStops
                ? "請從側邊欄選擇輕鐵車站。"
                : "請從側邊欄選擇輕鐵路線。"
        case .simplifiedChinese:
            showsStops
                ? "请从侧边栏选择轻铁车站。"
                : "请从侧边栏选择轻铁路线。"
        }
    }

    private var routeList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(LightRailRoute.regularRoutes) { route in
                    Group {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            Button {
                                selectedRouteID = route.id
                                selectedRouteStop = nil
                            } label: {
                                routeRow(route)
                            }
                        } else {
                            NavigationLink {
                                LightRailRouteDetailView(route: route)
                            } label: {
                                routeRow(route)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Text("Choose a route, then tap a stop for live arrivals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)

                Link(destination: URL(string: "https://www.mtr.com.hk/en/customer/services/routemap_index.html")!) {
                    Label("Official Light Rail Route Map", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .customInfoCardSurface(cornerRadius: 22)
                }
                .foregroundStyle(.primary)
            }
            .padding(16)
        }
    }

    private func routeRow(_ route: LightRailRoute) -> some View {
        HStack(spacing: 16) {
                        Text(route.id)
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(route.usesDarkText ? Color.black : Color.white)
                            .frame(width: 76, height: 44)
                            .background(route.color, in: Capsule())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(route.title(for: language))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(.primary)
                    .padding(16)
                    .customInfoCardSurface(cornerRadius: 22)
    }
}

struct LightRailRoute: Identifiable {
    let id: String
    let english: String
    let traditional: String
    let simplified: String
    let rgb: UInt32
    var usesDarkText = false

    var color: Color {
        Color(
            red: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255
        )
    }

    func title(for language: TransitLanguage) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }

    // Regular routes and colour families verified against MTR's official map,
    // 2026-08-31. RGB values are visual approximations, not published brand codes.
    // https://www.mtr.com.hk/en/customer/images/services/LR_routemap_s.jpg
    // Special/peak-only variants are deliberately excluded from this first list.
    static let regularRoutes: [Self] = [
        .init(id: "505", english: "Sam Shing ↔ Siu Hong", traditional: "三聖 ↔ 兆康", simplified: "三圣 ↔ 兆康", rgb: 0xD32630),
        .init(id: "507", english: "Tuen Mun Ferry Pier ↔ Tin King", traditional: "屯門碼頭 ↔ 田景", simplified: "屯门码头 ↔ 田景", rgb: 0x00A651, usesDarkText: true),
        .init(id: "610", english: "Tuen Mun Ferry Pier ↔ Yuen Long", traditional: "屯門碼頭 ↔ 元朗", simplified: "屯门码头 ↔ 元朗", rgb: 0x6B342F),
        .init(id: "614", english: "Tuen Mun Ferry Pier ↔ Yuen Long", traditional: "屯門碼頭 ↔ 元朗", simplified: "屯门码头 ↔ 元朗", rgb: 0x00BCE4, usesDarkText: true),
        .init(id: "614P", english: "Tuen Mun Ferry Pier ↔ Siu Hong", traditional: "屯門碼頭 ↔ 兆康", simplified: "屯门码头 ↔ 兆康", rgb: 0xF08B95, usesDarkText: true),
        .init(id: "615", english: "Tuen Mun Ferry Pier ↔ Yuen Long", traditional: "屯門碼頭 ↔ 元朗", simplified: "屯门码头 ↔ 元朗", rgb: 0xFFE500, usesDarkText: true),
        .init(id: "615P", english: "Tuen Mun Ferry Pier ↔ Siu Hong", traditional: "屯門碼頭 ↔ 兆康", simplified: "屯门码头 ↔ 兆康", rgb: 0x007D9D),
        .init(id: "705", english: "Tin Shui Wai Circular", traditional: "天水圍循環綫", simplified: "天水围循环线", rgb: 0x76B841, usesDarkText: true),
        .init(id: "706", english: "Tin Shui Wai Circular", traditional: "天水圍循環綫", simplified: "天水围循环线", rgb: 0xAF71B0, usesDarkText: true),
        .init(id: "751", english: "Tin Yat ↔ Yau Oi", traditional: "天逸 ↔ 友愛", simplified: "天逸 ↔ 友爱", rgb: 0xF58220, usesDarkText: true),
        .init(id: "761P", english: "Tin Yat ↔ Yuen Long", traditional: "天逸 ↔ 元朗", simplified: "天逸 ↔ 元朗", rgb: 0x6D2780)
    ]
}

#Preview {
    NavigationStack {
        LightRailView()
    }
}
