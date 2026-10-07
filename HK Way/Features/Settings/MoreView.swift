//
//  MoreView.swift
//  HK Way
//
//  Created by Codex on 23/8/2026.
//

import SwiftUI
import SwiftData

struct MoreView: View {
    @Environment(\.transitLanguage) private var transitLanguage
    @State private var tunnelTraffic = TunnelTrafficStore()
    let onClose: () -> Void
    let onSelectTab: (AppTab) -> Void
    let onSelectDestination: (SideMenuDestination) -> Void

    init(
        onClose: @escaping () -> Void = {},
        onSelectTab: @escaping (AppTab) -> Void = { _ in },
        onSelectDestination: @escaping (SideMenuDestination) -> Void = { _ in }
    ) {
        self.onClose = onClose
        self.onSelectTab = onSelectTab
        self.onSelectDestination = onSelectDestination
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelectDestination(.weather)
                    } label: {
                        menuRow(
                            title: transitLanguage.newsText(
                                "Weather Report",
                                "天氣報告",
                                "天气报告"
                            ),
                            subtitle: transitLanguage.newsText("Current conditions and forecast", "目前天氣及預報", "当前天气及预报"),
                            systemImage: "cloud.sun.fill",
                            color: .orange
                        )
                    }

                    Button {
                        onSelectDestination(.traffic)
                    } label: {
                        menuRow(
                            title: transitLanguage.newsText(
                                "Traffic News",
                                "交通消息",
                                "交通消息"
                            ),
                            subtitle: transitLanguage.newsText("Live incidents and transport notices", "即時事故及交通通告", "实时事故及交通通告"),
                            systemImage: "car.fill",
                            color: .red
                        )
                    }

                    Button {
                        onSelectDestination(.tunnelTraffic)
                    } label: {
                        menuRow(
                            title: transitLanguage.newsText(
                                "Road Traffic",
                                "道路交通",
                                "道路交通"
                            ),
                            subtitle: transitLanguage.newsText("Tunnel times and road conditions", "隧道時間及道路狀況", "隧道时间及道路状况"),
                            systemImage: "road.lanes",
                            color: .blue,
                            showsWarning: tunnelTraffic.hasJourneyOverTenMinutes
                        )
                    }
                } header: {
                    Text(
                        transitLanguage.newsText(
                            "News",
                            "最新消息",
                            "最新消息"
                        )
                    )
                }

                Section {
                    Button {
                        onSelectTab(.favorites)
                    } label: {
                        menuRow(
                            title: localized("Favorites"),
                            subtitle: transitLanguage.newsText("Your saved routes and stops", "已收藏的路線及車站", "已收藏的路线及车站"),
                            systemImage: "bookmark",
                            color: .accentColor
                        )
                    }

                    Button {
                        onSelectTab(.nearby)
                    } label: {
                        menuRow(
                            title: localized("Nearby"),
                            subtitle: transitLanguage.newsText("Find transport around you", "尋找附近交通服務", "寻找附近交通服务"),
                            systemImage: "location.fill",
                            color: .accentColor
                        )
                    }

                    Button {
                        onSelectDestination(.planner)
                    } label: {
                        menuRow(
                            title: journeyPlannerTitle,
                            subtitle: journeyPlannerSubtitle,
                            systemImage: "arrow.triangle.branch",
                            color: .accentColor
                        )
                    }
                } header: {
                    Text(planJourneyTitle)
                }

                ForEach(MoreTransportCategory.allCases) { category in
                    Section {
                        if category == .busServices {
                            Button {
                                onSelectDestination(.kmbStopLookup)
                            } label: {
                                menuRow(
                                    title: transitLanguage.newsText(
                                        "KMB Stop Number",
                                        "九巴車站編號",
                                        "九巴车站编号"
                                    ),
                                    subtitle: transitLanguage.newsText(
                                        "Look up a stop directly",
                                        "輸入編號直接查詢車站",
                                        "输入编号直接查询车站"
                                    ),
                                    systemImage: "number.square.fill",
                                    color: .red
                                )
                            }
                        }

                        ForEach(category.services) { service in
                            Button {
                                onSelectDestination(.service(service))
                            } label: {
                                menuRow(
                                    title: localized(service.title),
                                    subtitle: serviceSubtitle(service),
                                    systemImage: service.systemImage,
                                    color: service.color
                                )
                            }
                        }
                    } header: {
                        Text(LocalizedStringKey(category.title))
                    }
                }

                Section {
                    Button {
                        onSelectDestination(.settings)
                    } label: {
                        menuRow(
                            title: localized("Settings"),
                            subtitle: transitLanguage.newsText("Language, appearance and preferences", "語言、外觀及偏好設定", "语言、外观及偏好设置"),
                            systemImage: "gearshape",
                            color: .secondary
                        )
                    }

                    Button {
                        onSelectDestination(.support)
                    } label: {
                        menuRow(
                            title: transitLanguage.newsText(
                                "Support Me",
                                "支持我",
                                "支持我"
                            ),
                            subtitle: transitLanguage.newsText("Optional tips to support HK Way", "自願打賞支持喂！香港", "自愿打赏支持喂！香港"),
                            systemImage: "heart.fill",
                            color: .pink
                        )
                    }

                    Link(destination: weiGuessWebsiteURL) {
                        weiGuessRow
                    }
                    .accessibilityHint(
                        transitLanguage.newsText(
                            "Opens the Wei! Guess website",
                            "開啟《喂！估吓啦～》網站",
                            "打开《喂！估吓啦～》网站"
                        )
                    )
                } header: {
                    Text(LocalizedStringKey("Settings"))
                } footer: {
                    Text(dataSourceAttribution)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

            }
            .listStyle(.plain)
            .listSectionSpacing(10)
            .environment(\.defaultMinListRowHeight, 38)
            .navigationTitle(menuTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(localized("Close"))
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                GlobalWeatherStrip(usesWeatherAwareBackground: true)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SidebarAdvertisementView()
            }
            .task { await tunnelTraffic.refresh() }
        }
    }

    private func serviceSubtitle(_ service: MoreTransportService) -> String {
        switch service {
        case .airportBus: return transitLanguage.newsText("Airport routes and district search", "機場巴士路線及地區搜尋", "机场巴士路线及地区搜索")
        case .residentBus: return transitLanguage.newsText("Residential estate bus services", "屋苑巴士服務", "屋苑巴士服务")
        case .portBus: return transitLanguage.newsText("Cross-boundary port bus services", "跨境口岸巴士服務", "跨境口岸巴士服务")
        case .crossBoundary: return transitLanguage.newsText("Travel to mainland border crossings", "前往內地口岸的交通", "前往内地口岸的交通")
        case .themePark: return transitLanguage.newsText("Routes for Hong Kong attractions", "前往主題樂園的路線", "前往主题乐园的路线")
        case .lrtFeederBus: return transitLanguage.newsText("MTR feeder buses in the northwest New Territories", "新界西北港鐵接駁巴士", "新界西北港铁接驳巴士")
        case .mtr: return transitLanguage.newsText("Station arrivals, routes and fares", "車站到站、路線及車費", "车站到站、路线及车费")
        case .lightRail: return transitLanguage.newsText("Light Rail stops and arrival times", "輕鐵車站及到站時間", "轻铁车站及到站时间")
        case .tram: return transitLanguage.newsText("Hong Kong Island tram services", "港島電車服務", "港岛电车服务")
        case .peakTram: return transitLanguage.newsText("Peak Tram service information", "山頂纜車服務資訊", "山顶缆车服务资讯")
        case .ferry: return transitLanguage.newsText("Ferry routes and sailing times", "渡輪航線及開航時間", "渡轮航线及开航时间")
        case .kaiTakEventRoutes: return transitLanguage.newsText("Transport for Kai Tak events", "啟德活動交通安排", "启德活动交通安排")
        case .racecourseRoutes: return transitLanguage.newsText("Race-day transport services", "賽馬日交通服務", "赛马日交通服务")
        case .sightseeingRoutes: return transitLanguage.newsText("Scenic routes around Hong Kong", "香港觀光路線", "香港观光路线")
        case .ngongPing360: return transitLanguage.newsText("Cable car service to Ngong Ping", "前往昂坪的纜車服務", "前往昂坪的缆车服务")
        case .tszShanMonastery: return transitLanguage.newsText("Travel to Tsz Shan Monastery", "前往慈山寺的交通", "前往慈山寺的交通")
        case .tianTanBuddha: return transitLanguage.newsText("Travel to the Tian Tan Buddha", "前往天壇大佛的交通", "前往天坛大佛的交通")
        case .maWan: return transitLanguage.newsText("Routes serving Ma Wan", "馬灣交通路線", "马湾交通路线")
        }
    }

    private var menuTitle: String {
        switch transitLanguage {
        case .english: "HK Way"
        case .traditionalChinese, .simplifiedChinese: "喂!香港"
        }
    }

    private var dataSourceAttribution: String {
        switch transitLanguage {
        case .english: "Data provided by data.gov.hk"
        case .traditionalChinese: "資料由 data.gov.hk 提供"
        case .simplifiedChinese: "数据由 data.gov.hk 提供"
        }
    }

    private var weiGuessWebsiteURL: URL {
        URL(string: "https://hkwayapp.github.io/")!
    }

    private var weiGuessRow: some View {
        HStack(spacing: 14) {
            Image("WeiGuessAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(transitLanguage.newsText("Wei! Guess", "喂！估吓啦～", "喂！估吓啦～"))
                    .foregroundStyle(.primary)

                Text(
                    transitLanguage.newsText(
                        "Cantonese emoji puzzle game",
                        "用 Emoji 猜地道廣東話",
                        "用 Emoji 猜地道粤语"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right.square")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 1)
    }

    private func localized(_ key: String) -> String {
        transitLanguage.localized(String.LocalizationValue(key))
    }

    private func menuRow(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        color: Color,
        showsWarning: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if showsWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityLabel(
                        transitLanguage.newsText(
                            "Tunnel journey time exceeds 10 minutes",
                            "隧道行車時間超過 10 分鐘",
                            "隧道行车时间超过 10 分钟"
                        )
                    )
            }
        }
        .padding(.vertical, 1)
    }

    private var journeyPlannerSubtitle: String {
        switch transitLanguage {
        case .english:
            "Local bus, rail, ferry and walking connections"
        case .traditionalChinese:
            "本地巴士、鐵路、渡輪及步行轉乘"
        case .simplifiedChinese:
            "本地巴士、铁路、渡轮及步行换乘"
        }
    }

    private var planJourneyTitle: String {
        switch transitLanguage {
        case .english: "Plan a Journey"
        case .traditionalChinese: "規劃行程"
        case .simplifiedChinese: "规划行程"
        }
    }

    private var journeyPlannerTitle: String {
        switch transitLanguage {
        case .english: "Journey Planner"
        case .traditionalChinese: "行程規劃"
        case .simplifiedChinese: "行程规划"
        }
    }

}

private struct KMBStopLookupMatch: Identifiable {
    let id: String
    let stop: StopEntity
    let journey: JourneyEntity
    let journeyStop: JourneyStopEntity
}

private struct KMBStopLookupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.transitLanguage) private var transitLanguage
    @State private var stopNumber = ""
    @State private var matches: [KMBStopLookupMatch] = []
    @FocusState private var isStopNumberFocused: Bool

    var body: some View {
        List {
            Section {
                TextField(prompt, text: $stopNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($isStopNumberFocused)
                    .onSubmit { isStopNumberFocused = false }
                    .onChange(of: stopNumber) { _, _ in
                        filterStops()
                    }
            } header: {
                Text(title)
            } footer: {
                Text(helpText)
            }

            if !normalizedStopNumber.isEmpty {
                Section(resultsTitle) {
                    if matches.isEmpty {
                        ContentUnavailableView(
                            noResultsTitle,
                            systemImage: "bus",
                            description: Text(noResultsDescription)
                        )
                    } else {
                        ForEach(matches) { match in
                            NavigationLink {
                                StopDetailView(
                                    stop: match.stop,
                                    journey: match.journey,
                                    journeyStop: match.journeyStop
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Text(match.journeyStop.publicStopCode ?? "—")
                                        .font(.subheadline.bold().monospaced())
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(minWidth: 54, minHeight: 38)
                                        .padding(.horizontal, 6)
                                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(match.stop.displayName(for: transitLanguage))
                                            .font(.headline)
                                        Text(match.journey.destinationStop?.displayName(for: transitLanguage) ?? "")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .simultaneousGesture(TapGesture().onEnded {
                    isStopNumberFocused = false
                })
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.accentColor)
        .onAppear { isStopNumberFocused = true }
        .onDisappear { isStopNumberFocused = false }
    }

    private var normalizedStopNumber: String {
        stopNumber
            .uppercased()
            .filter { !$0.isWhitespace }
    }

    private func filterStops() {
        let code = normalizedStopNumber
        guard !code.isEmpty else {
            matches = []
            return
        }

        let descriptor = FetchDescriptor<JourneyStopEntity>(
            predicate: #Predicate { $0.publicStopCode != nil }
        )
        let journeyStops = (try? modelContext.fetch(descriptor)) ?? []
        var seenStopIDs = Set<String>()
        matches = journeyStops
            .filter { journeyStop in
                journeyStop.publicStopCode?.uppercased().contains(code) == true
            }
            .compactMap { journeyStop in
                guard let stop = journeyStop.stop,
                      let journey = journeyStop.journey,
                      seenStopIDs.insert(stop.id).inserted
                else { return nil }
                return KMBStopLookupMatch(
                    id: journeyStop.id,
                    stop: stop,
                    journey: journey,
                    journeyStop: journeyStop
                )
            }
            .prefix(30)
            .map { $0 }
    }

    private var title: String {
        transitLanguage.newsText("KMB Stop Number", "九巴車站編號", "九巴车站编号")
    }

    private var prompt: String {
        transitLanguage.newsText("Enter KMB stop number", "輸入九巴車站編號", "输入九巴车站编号")
    }

    private var helpText: String {
        transitLanguage.newsText(
            "Start typing the code printed on a KMB stop pole, for example A1 or TW371.",
            "輸入九巴站柱上的編號即時篩選，例如 A1 或 TW371。",
            "输入九巴站柱上的编号即时筛选，例如 A1 或 TW371。"
        )
    }

    private var searchTitle: String {
        transitLanguage.newsText("Look Up Stop", "查詢車站", "查询车站")
    }

    private var resultsTitle: String {
        transitLanguage.newsText("Results", "搜尋結果", "搜索结果")
    }

    private var noResultsTitle: String {
        transitLanguage.newsText("No KMB stop found", "找不到九巴車站", "找不到九巴车站")
    }

    private var noResultsDescription: String {
        transitLanguage.newsText(
            "Check the stop number and try again.",
            "請檢查車站編號後再試。",
            "请检查车站编号后再试。"
        )
    }
}

enum SideMenuDestination: Hashable, Identifiable {
    case weather
    case traffic
    case tunnelTraffic
    case planner
    case kmbStopLookup
    case settings
    case support
    case service(MoreTransportService)

    var id: String {
        switch self {
        case .weather: "weather"
        case .traffic: "traffic"
        case .tunnelTraffic: "tunnel-traffic"
        case .planner: "planner"
        case .kmbStopLookup: "kmb-stop-lookup"
        case .settings: "settings"
        case .support: "support"
        case .service(let service): "service-\(service.rawValue)"
        }
    }
}

struct SideMenuDestinationView: View {
    let destination: SideMenuDestination

    var body: some View {
        switch destination {
        case .weather:
            NewsView(content: .weather)
        case .traffic:
            NewsView(content: .traffic)
        case .tunnelTraffic:
            TunnelTrafficView()
        case .planner:
            UniversalJourneyPlannerView()
        case .kmbStopLookup:
            KMBStopLookupView()
        case .settings:
            SettingsView()
        case .support:
            SupportView()
        case .service(let service):
            serviceDestination(for: service)
        }
    }

    @ViewBuilder
    private func serviceDestination(for service: MoreTransportService) -> some View {
        ZStack {
            MoreTransportBackgroundView(color: service.color)

            Group {
                switch service {
                case .airportBus:
                    AirportBusView()
                case .residentBus:
                    ResidentBusView()
                case .portBus:
                    PortBusView()
                case .crossBoundary:
                    CrossBoundaryView()
                case .themePark:
                    ThemeParkView()
                case .lrtFeederBus:
                    LRTFeederBusView()
                case .lightRail:
                    LightRailView()
                case .mtr:
                    MTRView()
                case .peakTram:
                    PeakTramView()
                case .tram:
                    TramView()
                case .tianTanBuddha:
                    TianTanBuddhaView()
                case .ngongPing360:
                    NgongPing360View()
                case .racecourseRoutes:
                    RacecourseView()
                case .ferry:
                    FerryView()
                case .maWan:
                    MaWanView()
                case .tszShanMonastery:
                    TszShanMonasteryView()
                case .kaiTakEventRoutes:
                    KaiTakEventRoutesView()
                case .sightseeingRoutes:
                    SightseeingRoutesView()
                }
            }
        }
    }
}

private struct MoreTransportBackgroundView: View {
    let color: Color

    var body: some View {
        LinearGradient(
            colors: [
                color.opacity(0.16),
                color.opacity(0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private enum MoreTransportCategory: String, CaseIterable, Identifiable {
    case busServices
    case railAndTram
    case marineTransport
    case boundaryServices
    case specialServices
    case sightseeingAndAttractions

    var id: Self { self }

    var title: String {
        switch self {
        case .busServices: "Bus Services"
        case .railAndTram: "Rail & Tram"
        case .marineTransport: "Marine Transport"
        case .boundaryServices: "Boundary Services"
        case .specialServices: "Special Services"
        case .sightseeingAndAttractions: "Sightseeing & Attractions"
        }
    }

    var services: [MoreTransportService] {
        MoreTransportService.allCases.filter { $0.category == self }
    }
}

enum MoreTransportService: String, CaseIterable, Identifiable {
    case airportBus
    case residentBus
    case portBus
    case crossBoundary
    case themePark
    case lrtFeederBus
    case mtr
    case lightRail
    case tram
    case peakTram
    case ferry
    case kaiTakEventRoutes
    case racecourseRoutes
    case sightseeingRoutes
    case ngongPing360
    case tszShanMonastery
    case tianTanBuddha
    case maWan

    var id: Self { self }

    fileprivate var category: MoreTransportCategory {
        switch self {
        case .airportBus, .residentBus, .lrtFeederBus:
            .busServices
        case .mtr, .lightRail, .tram, .peakTram, .ngongPing360:
            .railAndTram
        case .ferry:
            .marineTransport
        case .portBus, .crossBoundary:
            .boundaryServices
        case .kaiTakEventRoutes, .racecourseRoutes:
            .specialServices
        case .themePark, .sightseeingRoutes, .tszShanMonastery,
             .tianTanBuddha, .maWan:
            .sightseeingAndAttractions
        }
    }

    var isAvailable: Bool {
        true
    }

    var title: String {
        switch self {
        case .airportBus: "Airport Bus"
        case .residentBus: "Resident Bus"
        case .portBus: "Port Bus"
        case .crossBoundary: "Cross-Boundary"
        case .themePark: "Theme Park Routes"
        case .lrtFeederBus: "LRT Feeder Bus"
        case .lightRail: "Light Rail (LRT)"
        case .mtr: "MTR"
        case .tram: "Tram"
        case .peakTram: "Peak Tram"
        case .ferry: "Ferry"
        case .kaiTakEventRoutes: "Kai Tak Event Routes"
        case .racecourseRoutes: "Racecourse Routes"
        case .sightseeingRoutes: "Sightseeing Routes"
        case .ngongPing360: "Ngong Ping 360 Cable Car"
        case .tszShanMonastery: "Tsz Shan Monastery"
        case .tianTanBuddha: "Tian Tan Buddha"
        case .maWan: "Ma Wan"
        }
    }

    var systemImage: String {
        switch self {
        case .airportBus: "airplane"
        case .residentBus: "building.2.fill"
        case .portBus: "point.bottomleft.forward.to.point.topright.scurvepath.fill"
        case .crossBoundary: "bus.fill"
        case .themePark: "ticket.fill"
        case .lrtFeederBus: "bus.fill"
        case .lightRail: "tram.fill"
        case .mtr: "tram.fill"
        case .tram: "tram.fill"
        case .peakTram: "cablecar.fill"
        case .ferry: "ferry.fill"
        case .kaiTakEventRoutes: "sportscourt.fill"
        case .racecourseRoutes: "flag.checkered"
        case .sightseeingRoutes: "binoculars.fill"
        case .ngongPing360: "cablecar.fill"
        case .tszShanMonastery: "building.columns.fill"
        case .tianTanBuddha: "mountain.2.fill"
        case .maWan: "mappin.and.ellipse"
        }
    }

    var color: Color {
        switch self {
        case .airportBus:
            .blue
        case .residentBus:
            .teal
        case .portBus:
            .orange
        case .crossBoundary:
            .indigo
        case .themePark:
            .purple
        case .lrtFeederBus:
            Color(red: 0.15, green: 0.32, blue: 0.62)
        case .lightRail:
            Color(red: 0.72, green: 0.48, blue: 0.08)
        case .mtr:
            Color(red: 0.60, green: 0.08, blue: 0.18)
        case .tram:
            Color(red: 0.08, green: 0.43, blue: 0.24)
        case .peakTram:
            Color(red: 0.38, green: 0.20, blue: 0.12)
        case .ferry:
            .cyan
        case .kaiTakEventRoutes:
            .red
        case .racecourseRoutes:
            Color(red: 0.10, green: 0.42, blue: 0.28)
        case .sightseeingRoutes:
            .pink
        case .ngongPing360:
            Color(red: 0.13, green: 0.58, blue: 0.78)
        case .tszShanMonastery:
            Color(red: 0.52, green: 0.36, blue: 0.20)
        case .tianTanBuddha:
            Color(red: 0.57, green: 0.38, blue: 0.16)
        case .maWan:
            .teal
        }
    }
}

private struct AdditionalOperatorView: View {

    let title: String
    let systemImage: String

    var body: some View {
        CustomCardView(
            imageIcon: systemImage,
            title: title,
            subTitle: "Services will appear here.",
            animated: false
        )
        .navigationTitle(
            Text(LocalizedStringKey(title))
        )
    }
}

#Preview {
    MoreView()
}
