import SwiftUI

private func sanitizedTVDisplayText(_ text: String) -> String {
    text.replacingOccurrences(
        of: #"(?i)</?br\s*/?>"#,
        with: " ",
        options: .regularExpression
    )
}

#if DEBUG
private enum TVWeatherWarningPreview: String, CaseIterable, Identifiable {
    case live
    case rainAmber, rainRed, rainBlack
    case monsoon, thunderstorm, veryHot, cold, frost, landslip, tsunami, fireDanger, preT8
    case t1, t3, t8NE, t8SE, t8SW, t8NW, t9, t10

    var id: Self { self }

    var warningCode: (kind: String, code: String)? {
        switch self {
        case .live: nil
        case .rainAmber: ("WRAIN", "WRAINA")
        case .rainRed: ("WRAIN", "WRAINR")
        case .rainBlack: ("WRAIN", "WRAINB")
        case .monsoon: ("WMSGNL", "WMSGNL")
        case .thunderstorm: ("WTS", "WTS")
        case .veryHot: ("WHOT", "WHOT")
        case .cold: ("WCOLD", "WCOLD")
        case .frost: ("WFROST", "WFROST")
        case .landslip: ("WL", "WL")
        case .tsunami: ("WTMW", "WTMW")
        case .fireDanger: ("WFIRE", "WFIRER")
        case .preT8: ("WTCPRE8", "WTCPRE8")
        case .t1: ("WTCSGNL", "TC1")
        case .t3: ("WTCSGNL", "TC3")
        case .t8NE: ("WTCSGNL", "TC8NE")
        case .t8SE: ("WTCSGNL", "TC8SE")
        case .t8SW: ("WTCSGNL", "TC8SW")
        case .t8NW: ("WTCSGNL", "TC8NW")
        case .t9: ("WTCSGNL", "TC9")
        case .t10: ("WTCSGNL", "TC10")
        }
    }

    func title(_ language: TVLanguage) -> String {
        switch self {
        case .live:
            language.text("Live HKO Data", "香港天文台即時資料", "香港天文台实时数据")
        case .rainAmber: language.text("Amber Rainstorm Warning", "黃色暴雨警告", "黄色暴雨警告")
        case .rainRed: language.text("Red Rainstorm Warning", "紅色暴雨警告", "红色暴雨警告")
        case .rainBlack: language.text("Black Rainstorm Warning", "黑色暴雨警告", "黑色暴雨警告")
        case .monsoon: language.text("Strong Monsoon Signal", "強烈季候風信號", "强烈季候风信号")
        case .thunderstorm: language.text("Thunderstorm Warning", "雷暴警告", "雷暴警告")
        case .veryHot: language.text("Very Hot Weather Warning", "酷熱天氣警告", "酷热天气警告")
        case .cold: language.text("Cold Weather Warning", "寒冷天氣警告", "寒冷天气警告")
        case .frost: language.text("Frost Warning", "霜凍警告", "霜冻警告")
        case .landslip: language.text("Landslip Warning", "山泥傾瀉警告", "山泥倾泻警告")
        case .tsunami: language.text("Tsunami Warning", "海嘯警告", "海啸警告")
        case .fireDanger: language.text("Fire Danger Warning", "火災危險警告", "火灾危险警告")
        case .preT8: language.text("Pre-No. 8 Special Announcement", "八號信號特別報告", "八号信号特别报告")
        case .t1:
            language.text("T1 Standby Signal", "一號戒備信號", "一号戒备信号")
        case .t3:
            language.text("T3 Strong Wind Signal", "三號強風信號", "三号强风信号")
        case .t8NE:
            language.text("T8 Northeast Gale or Storm Signal", "八號東北烈風或暴風信號", "八号东北烈风或暴风信号")
        case .t8SE:
            language.text("T8 Southeast Gale or Storm Signal", "八號東南烈風或暴風信號", "八号东南烈风或暴风信号")
        case .t8SW:
            language.text("T8 Southwest Gale or Storm Signal", "八號西南烈風或暴風信號", "八号西南烈风或暴风信号")
        case .t8NW:
            language.text("T8 Northwest Gale or Storm Signal", "八號西北烈風或暴風信號", "八号西北烈风或暴风信号")
        case .t9:
            language.text("T9 Increasing Gale or Storm Signal", "九號烈風或暴風風力增強信號", "九号烈风或暴风风力增强信号")
        case .t10:
            language.text("T10 Hurricane Signal", "十號颶風信號", "十号飓风信号")
        }
    }

    func warning(_ language: TVLanguage) -> TVWeatherWarning? {
        guard let warningCode else { return nil }
        return TVWeatherWarning(
            name: title(language),
            kind: warningCode.kind,
            code: warningCode.code,
            issuedAt: .now,
            updatedAt: .now
        )
    }
}

private enum TVFestivalPreview: String, CaseIterable, Identifiable {
    case live, newYear, lunarNewYear, lanternFestival, labourDay, buddhasBirthday
    case dragonBoat, establishmentDay, midAutumn, nationalDay, chungYeung, christmas

    var id: Self { self }

    func title(_ language: TVLanguage) -> String {
        switch self {
        case .live: language.text("Automatic Date", "按日期自動顯示", "按日期自动显示")
        case .newYear: language.text("New Year", "新年", "新年")
        case .lunarNewYear: language.text("Lunar New Year", "農曆新年", "农历新年")
        case .lanternFestival: language.text("Lantern Festival", "元宵節", "元宵节")
        case .labourDay: language.text("Labour Day", "勞動節", "劳动节")
        case .buddhasBirthday: language.text("Buddha's Birthday", "佛誕", "佛诞")
        case .dragonBoat: language.text("Dragon Boat Festival", "端午節", "端午节")
        case .establishmentDay: language.text("HKSAR Establishment Day", "香港特別行政區成立紀念日", "香港特别行政区成立纪念日")
        case .midAutumn: language.text("Mid-Autumn Festival", "中秋節", "中秋节")
        case .nationalDay: language.text("National Day", "國慶日", "国庆日")
        case .chungYeung: language.text("Chung Yeung Festival", "重陽節", "重阳节")
        case .christmas: language.text("Christmas", "聖誕節", "圣诞节")
        }
    }

    func greeting(_ language: TVLanguage) -> String? {
        switch self {
        case .live: nil
        case .newYear: language.text("Happy New Year!", "新年快樂！", "新年快乐！")
        case .lunarNewYear: language.text("Happy Lunar New Year!", "農曆新年快樂！", "农历新年快乐！")
        case .lanternFestival: language.text("Happy Lantern Festival!", "元宵節快樂！", "元宵节快乐！")
        case .labourDay: language.text("Happy Labour Day!", "勞動節快樂！", "劳动节快乐！")
        case .buddhasBirthday: language.text("Happy Buddha's Birthday!", "佛誕吉祥！", "佛诞吉祥！")
        case .dragonBoat: language.text("Happy Dragon Boat Festival!", "端午節快樂！", "端午节快乐！")
        case .establishmentDay: language.text("Happy HKSAR Establishment Day!", "香港特別行政區成立紀念日快樂！", "香港特别行政区成立纪念日快乐！")
        case .midAutumn: language.text("Happy Mid-Autumn Festival!", "中秋節快樂！", "中秋节快乐！")
        case .nationalDay: language.text("Happy National Day!", "國慶日快樂！", "国庆日快乐！")
        case .chungYeung: language.text("Happy Chung Yeung Festival!", "重陽節快樂！", "重阳节快乐！")
        case .christmas: language.text("Merry Christmas!", "聖誕快樂！", "圣诞快乐！")
        }
    }
}
#endif

struct TVRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("tvLanguage") private var language = TVLanguage.traditionalChinese
    @AppStorage("tvBackgroundSelection") private var backgroundSelection = TVBackgroundPreview.automatic
    @State private var busData = TVBusDataStore()
    @State private var weatherBackground = TVWeatherBackgroundStore()
    @State private var trafficNews = TVTrafficNewsStore()

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let viewportSize = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )

            TabView {
                Tab(language.text("Home", "主頁", "主页"), systemImage: "rectangle.split.2x1.fill") {
                    TVHomeDashboard(data: busData, weather: weatherBackground, trafficNews: trafficNews, language: language)
                }
                Tab(language.text("Routes", "路線", "路线"), systemImage: "bus.doubledecker.fill") {
                    NavigationStack { TVRoutesView(data: busData, language: language) }
                }
                Tab(language.text("Settings", "設定", "设置"), systemImage: "gearshape.fill") {
                    NavigationStack { TVSettingsView(language: $language) }
                }
            }
            .environment(\.tvViewportSize, viewportSize)
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, language.locale)
        .environment(\.tvBackgroundImageName, selectedBackgroundImageName)
        .animation(.easeInOut(duration: 1.2), value: weatherBackground.imageName)
        .task { await busData.load() }
        .task(id: language) {
            while !Task.isCancelled {
                await weatherBackground.refresh(language: language)
                try? await Task.sleep(for: .seconds(300))
            }
        }
        .task(id: language) {
            while !Task.isCancelled {
                await trafficNews.refresh(language: language)
                try? await Task.sleep(for: .seconds(300))
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await weatherBackground.refresh(language: language)
                await trafficNews.refresh(language: language)
            }
        }
    }

    private var selectedBackgroundImageName: String {
        backgroundSelection.imageName ?? weatherBackground.imageName
    }
}

private struct TVHomeDashboard: View {
    @Environment(\.scenePhase) private var scenePhase
    let data: TVBusDataStore
    let weather: TVWeatherBackgroundStore
    let trafficNews: TVTrafficNewsStore
    let language: TVLanguage
    @AppStorage("tvUserName") private var userName = ""
    @AppStorage(TVBusFavorites.storageKey) private var storedFavorites = ""
    @State private var etaStore = TVETAStore()
    @State private var trafficNoticeIndex = 0
    @State private var etaPageIndex = 0
    @State private var weatherWarningIndex = 0
#if DEBUG
    @AppStorage("tvDebugWeatherWarningPreview") private var warningPreviewRaw = TVWeatherWarningPreview.live.rawValue
    @AppStorage("tvDebugTrafficNewsPreview") private var showsTrafficNewsPreview = false
#endif

    private var favorites: [TVFavoriteBusRoute] { TVBusFavorites.decode(storedFavorites) }

    private var displayedWarnings: [TVWeatherWarning] {
#if DEBUG
        let preview = TVWeatherWarningPreview(rawValue: warningPreviewRaw) ?? .live
        if let warning = preview.warning(language) {
            return [warning] + weather.activeWarnings.filter { $0.kind != warning.kind }
        }
#endif
        return weather.activeWarnings
    }

    private var displayedWarning: TVWeatherWarning? {
        guard !displayedWarnings.isEmpty else { return nil }
        return displayedWarnings[min(weatherWarningIndex, displayedWarnings.count - 1)]
    }

    private var displayedTrafficNotices: [TVTrafficNotice] {
#if DEBUG
        if showsTrafficNewsPreview {
            return [
                TVTrafficNotice(
                    id: "preview-traffic-1",
                    heading: language.text("Road Incident", "道路事故", "道路事故"),
                    location: language.text("Cross-Harbour Tunnel", "紅磡海底隧道", "红磡海底隧道"),
                    content: language.text(
                        "Traffic is slow near the tunnel entrance. Allow extra travelling time and consider an alternative route.",
                        "海底隧道入口附近交通繁忙，請預留額外行車時間，並考慮使用其他路線。",
                        "海底隧道入口附近交通繁忙，请预留额外行车时间，并考虑使用其他路线。"
                    ),
                    announcedAt: .now.addingTimeInterval(-8 * 60)
                ),
                TVTrafficNotice(
                    id: "preview-traffic-2",
                    heading: language.text("Emergency Roadworks", "緊急道路工程", "紧急道路工程"),
                    location: language.text("Gloucester Road", "告士打道", "告士打道"),
                    content: language.text(
                        "One lane is closed near the junction. Motorists should follow temporary traffic signs and drive with care.",
                        "近交界處有一條行車線封閉，駕駛人士請遵從臨時交通標誌並小心駕駛。",
                        "近交界处有一条行车线封闭，驾驶人士请遵从临时交通标志并小心驾驶。"
                    ),
                    announcedAt: .now.addingTimeInterval(-18 * 60)
                ),
                TVTrafficNotice(
                    id: "preview-traffic-3",
                    heading: language.text("Special Traffic Arrangement", "特別交通安排", "特别交通安排"),
                    location: language.text("Hong Kong Island", "香港島", "香港岛"),
                    content: language.text(
                        "Temporary diversions are in place because of an event. Several bus routes may be redirected, and journey times may be longer than usual. Please follow instructions from officers at the scene.",
                        "因應活動實施臨時改道，多條巴士路線可能需要改道，行程時間亦可能較平日長。請遵從現場人員指示。",
                        "因应活动实施临时改道，多条巴士路线可能需要改道，行程时间亦可能较平日长。请遵从现场人员指示。"
                    ),
                    announcedAt: .now.addingTimeInterval(-28 * 60)
                )
            ]
        }
#endif
        return trafficNews.notices
    }

    private var dashboardTrafficNotices: [TVTrafficNotice] {
        Array(displayedTrafficNotices.prefix(12))
    }

    private var trafficNoticePages: [[TVTrafficNotice]] {
        let notices = dashboardTrafficNotices
        var pages: [[TVTrafficNotice]] = []
        var index = 0

        while index < notices.count {
            let notice = notices[index]
            if isLongTrafficNotice(notice) {
                pages.append([notice])
                index += 1
            } else if index + 1 < notices.count,
                      !isLongTrafficNotice(notices[index + 1]) {
                pages.append([notice, notices[index + 1]])
                index += 2
            } else {
                pages.append([notice])
                index += 1
            }
        }

        return pages
    }

    private func isLongTrafficNotice(_ notice: TVTrafficNotice) -> Bool {
        let characterLimit = language == .english ? 150 : 72
        return notice.content.count > characterLimit
    }

    var body: some View {
        dashboardContent
            .tvScenicBackground()
            .task(id: storedFavorites) {
                while !Task.isCancelled {
                    guard !data.routes.isEmpty else {
                        try? await Task.sleep(for: .seconds(1))
                        continue
                    }
                    await etaStore.refresh(favorites: favorites, data: data)
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .task(id: dashboardTrafficNotices.map { "\($0.id):\($0.content.count)" } + [language.rawValue]) {
                trafficNoticeIndex = 0
                let pageCount = trafficNoticePages.count
                guard pageCount > 1 else { return }

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(12))
                    } catch {
                        break
                    }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        trafficNoticeIndex = (trafficNoticeIndex + 1) % pageCount
                    }
                }
            }
            .task(id: favorites.map(\.id)) {
                etaPageIndex = 0
                let pageCount = Int(ceil(Double(favorites.count) / 4.0))
                guard pageCount > 1 else { return }

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(12))
                    } catch {
                        break
                    }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        etaPageIndex = (etaPageIndex + 1) % pageCount
                    }
                }
            }
            .task(id: displayedWarnings.map { "\($0.kind):\($0.code)" }) {
                weatherWarningIndex = 0
                guard displayedWarnings.count > 1 else { return }

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(12))
                    } catch {
                        break
                    }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        weatherWarningIndex = (weatherWarningIndex + 1) % displayedWarnings.count
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    trafficNoticeIndex = 0
                    etaPageIndex = 0
                    weatherWarningIndex = 0
                }
            }
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        Text(language == .english ? "HK Way" : "喂!香港")
                            .font(.system(size: 42, weight: .bold))
                        Text("-")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        TVGreetingMarquee(
                            language: language,
                            userName: userName,
                            weather: weather.currentWeather,
                            warnings: displayedWarnings
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 48)
                    }
                    .frame(width: proxy.size.width * 0.8, alignment: .leading)

                    Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                        .frame(width: proxy.size.width * 0.2, alignment: .trailing)
                }
            }
            .frame(height: 52)
            .containerRelativeFrame(.horizontal) { length, _ in
                length * 0.94
            }

            HStack(alignment: .top, spacing: 30) {
                dashboardCard {
                    VStack(alignment: .leading, spacing: 18) {
                        weatherContent
                        Divider()
                        trafficNewsContent
                    }
                }

                dashboardCard {
                    favoriteRoutesContent
                }
            }
            .frame(maxHeight: .infinity)
            .containerRelativeFrame(.horizontal) { length, _ in
                length * 0.94
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 50)
    }

    @ViewBuilder
    private var trafficNewsContent: some View {
        let pages = trafficNoticePages
        let pageCount = pages.count
        let safePage = min(trafficNoticeIndex, max(pageCount - 1, 0))
        let pageNotices = pages.indices.contains(safePage) ? pages[safePage] : []
        let isSingleNoticePage = pageNotices.count == 1

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(language.text("Traffic News", "交通消息", "交通消息"), systemImage: "car.side.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if pageCount > 1 {
                    Text("(\(safePage + 1)/\(pageCount))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            if !pageNotices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(pageNotices.enumerated()), id: \.element.id) { index, notice in
                        if index > 0 {
                            Divider()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if !notice.location.isEmpty {
                                Text(notice.location)
                                    .font(.callout.bold())
                                    .lineLimit(1)
                            }
                            Text(notice.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(isSingleNoticePage ? 10 : 4)
                                .fixedSize(horizontal: false, vertical: true)
                            if let announcedAt = notice.announcedAt {
                                HStack(spacing: 5) {
                                    Text(language.text("Reported", "發布於", "发布于"))
                                    Text(announcedAt, format: .dateTime.hour().minute())
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .id(safePage)
                .transition(.opacity)
            } else if trafficNews.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if trafficNews.hasError {
                Label(
                    language.text("Traffic news unavailable", "未能取得交通消息", "未能取得交通消息"),
                    systemImage: "wifi.exclamationmark"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(language.text("No special traffic notices", "暫無特別交通消息", "暂无特别交通消息"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var weatherContent: some View {
        if let current = weather.currentWeather {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 22) {
                    Image(systemName: current.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 48))
                    VStack(alignment: .leading, spacing: 4) {
                        if let temperature = current.temperature {
                            HStack(spacing: 16) {
                                Text(temperature.formatted(.number.precision(.fractionLength(0))) + "°")
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                ForEach(displayedWarnings) { warning in
                                    weatherWarningIcon(warning)
                                }
                            }
                        }
                        Text(current.condition(language))
                            .font(.subheadline)
                    }
                }

                if let warning = displayedWarning {
                    HStack(spacing: 10) {
                        Text(warning.name)
                            .font(.caption.bold())
                            .lineLimit(1)
                        if displayedWarnings.count > 1 {
                            Text("(\(min(weatherWarningIndex, displayedWarnings.count - 1) + 1)/\(displayedWarnings.count))")
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if let updatedAt = warning.updatedAt ?? warning.issuedAt {
                            Text(updatedAt, format: .dateTime.hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.orange.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    .id("warning:\(warning.kind):\(warning.code)")
                    .transition(.opacity)
                }

                if let tip = weather.specialWeatherTips.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            language.text("Special Weather Tip", "特別天氣提示", "特别天气提示"),
                            systemImage: "info.circle.fill"
                        )
                        .font(.caption.bold())
                        Text(tip.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(7)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                }

                HStack(spacing: 22) {
                    if let humidity = current.humidity {
                        Label(
                            language.text("Humidity ", "濕度 ", "湿度 ")
                                + humidity.formatted(.number.precision(.fractionLength(0))) + "%",
                            systemImage: "humidity.fill"
                        )
                    }
                    if let rainfall = current.rainfall {
                        Label(
                            language.text("Rain ", "雨量 ", "雨量 ")
                                + rainfall.formatted(.number.precision(.fractionLength(0))) + " mm",
                            systemImage: "drop.fill"
                        )
                    }
                    if let uvIndex = current.uvIndex {
                        Label(
                            language.text("UV ", "紫外線 ", "紫外线 ")
                                + uvIndex.formatted(.number.precision(.fractionLength(0))),
                            systemImage: "sun.max.fill"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(language.text("Updated ", "更新於 ", "更新于 ")
                     + current.updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if weather.hasWeatherError {
                    Label(
                        language.text("Showing the last weather update", "現正顯示上次天氣資料", "正在显示上次天气资料"),
                        systemImage: "wifi.exclamationmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } else if weather.hasWeatherError {
            Label(
                language.text("Weather unavailable", "未能取得天氣資料", "未能取得天气资料"),
                systemImage: "wifi.exclamationmark"
            )
            .font(.headline)
            .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 16) {
                ProgressView()
                Text(language.text("Loading Hong Kong weather…", "正在載入香港天氣…", "正在载入香港天气…"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func weatherWarningIcon(_ warning: TVWeatherWarning) -> some View {
        if let rainfallLevel = warning.rainfallSignalLevel {
            rainfallSignalBadge(rainfallLevel)
        } else if let artworkName = warning.typhoonArtworkName {
            Image(artworkName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 62, height: 62)
                .accessibilityHidden(true)
        } else {
            generalWeatherWarningBadge(warning)
        }
    }

    private func rainfallSignalBadge(_ level: TVRainfallSignalLevel) -> some View {
        let appearance: (color: Color, label: String) = switch level {
        case .amber: (.orange, "Amber")
        case .red: (.red, "Red")
        case .black: (.black, "Black")
        }

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(appearance.color)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.8), lineWidth: level == .black ? 2 : 0)
            VStack(spacing: 0) {
                Image(systemName: "cloud.heavyrain.fill")
                    .font(.system(size: 25, weight: .bold))
                Text(appearance.label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 76, height: 62)
        .accessibilityHidden(true)
    }

    private func generalWeatherWarningBadge(_ warning: TVWeatherWarning) -> some View {
        let color: Color = switch warning.kind {
        case "WMSGNL": .orange
        case "WTS": .purple
        case "WHOT": .orange
        case "WCOLD", "WFROST": .cyan
        case "WL": .brown
        case "WFNTSA", "WTMW": .blue
        case "WFIRE": .red
        case "WTCPRE8": .indigo
        default: .yellow
        }
        let foreground: Color = warning.kind == "WL" || warning.kind == "WFIRE" ? .white : .black

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
            Image(systemName: warning.symbolName)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(foreground)
        }
        .frame(width: 62, height: 62)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var favoriteRoutesContent: some View {
        if favorites.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                Label(language.text("No ETA Display Routes", "尚未加入到站顯示路線", "尚未加入到站显示路线"), systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Text(language.text(
                    "Add a route to the ETA Display from the Routes tab. Live arrival times will be shown here in large type.",
                    "請在「路線」分頁將路線加入到站顯示。即時到站時間將以大字顯示在這裡。",
                    "请在“路线”分页将路线加入到站显示。实时到站时间将以大字显示在这里。"
                ))
                .font(.headline)
                .foregroundStyle(.secondary)
            }
        } else {
            let pageSize = 4
            let pageCount = Int(ceil(Double(favorites.count) / Double(pageSize)))
            let safePage = min(etaPageIndex, max(pageCount - 1, 0))
            let firstIndex = safePage * pageSize
            let endIndex = min(firstIndex + pageSize, favorites.count)
            let visibleFavorites = Array(favorites[firstIndex..<endIndex])

            VStack(spacing: 8) {
                if favorites.count > pageSize {
                    HStack {
                        Spacer()
                        Text(
                            firstIndex + 1 == endIndex
                                ? "(\(endIndex)/\(favorites.count))"
                                : "(\(firstIndex + 1)–\(endIndex)/\(favorites.count))"
                        )
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    }
                }

                ForEach(visibleFavorites) { favorite in
                    HStack(spacing: 16) {
                        Text(favorite.number)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                            .frame(width: 90, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            boardingStopContent(for: favorite)
                            Text(
                                favorite.selectedStop(language) == nil
                                    ? sanitizedTVDisplayText(favorite.origin(language))
                                    : language.text("Towards ", "往 ", "往 ")
                                        + sanitizedTVDisplayText(favorite.destination(language))
                            )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .layoutPriority(1)
                        Spacer()
                        etaContent(for: favorite)
                    }
                    .padding(.vertical, 8)
                    if favorite.id != visibleFavorites.last?.id { Divider() }
                }

                if let updatedAt = etaStore.latestUpdatedAt {
                    HStack {
                        Spacer()
                        Text(updatedText(updatedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .id(safePage)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func etaContent(for favorite: TVFavoriteBusRoute) -> some View {
        switch etaStore.status(for: favorite) {
        case .idle, .loading:
            ProgressView()
                .frame(width: 210)
        case .available(let arrivals, _):
            VStack(alignment: .trailing, spacing: 5) {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    VStack(alignment: .trailing, spacing: 2) {
                        if let nearest = arrivals.first {
                            Text(arrivalText(nearest, now: context.date))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            ForEach(Array(arrivals.dropFirst().prefix(2))) { arrival in
                                Text(arrivalText(arrival, now: context.date))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(minWidth: 180, alignment: .trailing)
        case .noService:
            statusText(
                language.text("No live ETA", "暫無即時到站時間", "暂无实时到站时间"),
                symbol: "moon.zzz"
            )
        case .unavailable:
            statusText(
                language.text("ETA unavailable", "未能取得到站時間", "未能取得到站时间"),
                symbol: "wifi.exclamationmark"
            )
        }
    }

    private func statusText(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout.bold())
            .foregroundStyle(.secondary)
            .frame(width: 230, alignment: .trailing)
    }

    private func arrivalText(_ arrival: TVArrival, now: Date) -> String {
        guard let eta = arrival.estimatedArrival else {
            return "—"
        }
        let interval = eta.timeIntervalSince(now)
        if interval <= 0 {
            return interval > -30
                ? language.text("Arrived", "已到站", "已到站")
                : language.text("Departing", "正在開出", "正在驶离")
        }
        let minutes = max(1, Int(ceil(interval / 60)))
        return language.text("\(minutes)m", "\(minutes)分", "\(minutes)分")
    }

    @ViewBuilder
    private func boardingStopContent(for favorite: TVFavoriteBusRoute) -> some View {
        if let selectedStop = favorite.selectedStop(language) {
            Text(language.text("Boarding at", "上車站", "上车站"))
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text(sanitizedTVDisplayText(selectedStop))
                .font(.caption.bold())
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        } else {
            Text(sanitizedTVDisplayText(favorite.destination(language)))
                .font(.caption.bold())
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    private func updatedText(_ date: Date) -> String {
        language.text("Updated ", "更新於 ", "更新于 ")
            + date.formatted(date: .omitted, time: .shortened)
    }

    private func operatorNames(_ ids: [String]) -> String {
        ids.flatMap { $0.split(separator: "+").map(String.init) }
            .compactMap { id in TVBusOperator.allCases.first { $0.id == id }?.name(language) }
            .joined(separator: " · ")
    }

    private func dashboardCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
            Spacer(minLength: 0)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30))
    }
}

private struct TVRoutesView: View {
    let data: TVBusDataStore
    let language: TVLanguage
    @State private var searchText = ""
    @AppStorage(TVOperatorSelection.storageKey) private var storedOperatorSelection = ""
    @AppStorage(TVBusFavorites.storageKey) private var storedDisplayRoutes = ""

    private var selectedOperatorIDs: Set<String> {
        TVOperatorSelection.ids(from: storedOperatorSelection)
    }

    private var enabledOperators: [TVBusOperator] {
        selectedOperatorIDs.isEmpty
            ? TVBusOperator.allCases
            : TVBusOperator.allCases.filter { selectedOperatorIDs.contains($0.id) }
    }

    private var searchResults: [TVBusRoute] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return data.routes.filter { $0.number.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if data.isLoading, data.routes.isEmpty {
                ProgressView(language.text("Loading bus routes…", "正在載入巴士路線⋯", "正在载入巴士路线⋯"))
            } else if data.error != nil, data.routes.isEmpty {
                ContentUnavailableView {
                    Label(language.text("Routes Unavailable", "未能載入路線", "未能载入路线"), systemImage: "wifi.exclamationmark")
                } description: {
                    Text(language.text("Check the network connection and try again.", "請檢查網絡連線後再試。", "请检查网络连接后再试。"))
                } actions: {
                    Button(language.text("Try Again", "再試一次", "再试一次")) { Task { await data.load() } }
                }
            } else {
                ScrollView {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 390), spacing: 28)], spacing: 28) {
                            NavigationLink {
                                TVETADisplayRoutesView(language: language)
                            } label: {
                                HStack(spacing: 22) {
                                    Image(systemName: "rectangle.on.rectangle")
                                        .font(.title)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(language.text("ETA Display Routes", "到站顯示路線", "到站显示路线"))
                                            .font(.headline.bold())
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                            .allowsTightening(true)
                                        Text(TVBusFavorites.decode(storedDisplayRoutes).count, format: .number)
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 30)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 135, alignment: .leading)
                            }
                            .buttonStyle(.card)

                            ForEach(enabledOperators) { busOperator in
                                NavigationLink {
                                    TVOperatorRoutesView(
                                        data: data,
                                        busOperator: busOperator,
                                        language: language
                                    )
                                } label: {
                                    HStack(spacing: 22) {
                                        Image(systemName: "bus.doubledecker.fill")
                                            .font(.title)
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(busOperator.name(language))
                                                .font(.headline.bold())
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                                .allowsTightening(true)
                                            Text(routeCount(for: busOperator), format: .number)
                                                .font(.headline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 30)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 135, alignment: .leading)
                                }
                                .buttonStyle(.card)
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 24)], spacing: 24) {
                            ForEach(searchResults) { route in
                                NavigationLink {
                                    TVRouteDirectionsView(data: data, route: route, language: language)
                                } label: {
                                    TVRouteCard(route: route, language: language)
                                }
                                .buttonStyle(.card)
                            }
                        }
                    }
                }
                .padding(60)
                .scrollClipDisabled()
            }
        }
        .navigationTitle(language.text("Routes", "路線", "路线"))
        .searchable(text: $searchText, prompt: language.text("Search all route numbers", "搜尋所有路線號碼", "搜索所有路线号码"))
        .tvScenicBackground()
    }

    private func routeCount(for busOperator: TVBusOperator) -> Int {
        data.routes.count { route in
            route.operatorIds.flatMap { $0.split(separator: "+").map(String.init) }
                .contains(busOperator.id)
        }
    }
}

private struct TVOperatorRoutesView: View {
    let data: TVBusDataStore
    let busOperator: TVBusOperator
    let language: TVLanguage

    private var routes: [TVBusRoute] {
        data.routes.filter { route in
            route.operatorIds.flatMap { $0.split(separator: "+").map(String.init) }
                .contains(busOperator.id)
        }
    }

    private var prefixes: [String] {
        Set(routes.compactMap { $0.number.first.map { String($0).uppercased() } })
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 26)], spacing: 26) {
                ForEach(prefixes, id: \.self) { prefix in
                    NavigationLink {
                        TVRoutePrefixView(
                            data: data,
                            busOperator: busOperator,
                            prefix: prefix,
                            language: language
                        )
                    } label: {
                        VStack(spacing: 8) {
                            Text(prefix)
                                .font(.system(size: 58, weight: .bold, design: .rounded))
                            Text(routes.count { $0.number.uppercased().hasPrefix(prefix) }, format: .number)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 125)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(60)
        }
        .scrollClipDisabled()
        .navigationTitle(busOperator.name(language))
        .tvScenicBackground()
    }
}

private struct TVRoutePrefixView: View {
    let data: TVBusDataStore
    let busOperator: TVBusOperator
    let prefix: String
    let language: TVLanguage

    private var routes: [TVBusRoute] {
        data.routes.filter { route in
            let operatorIDs = route.operatorIds.flatMap { $0.split(separator: "+").map(String.init) }
            return operatorIDs.contains(busOperator.id)
                && route.number.uppercased().hasPrefix(prefix)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 24)], spacing: 24) {
                ForEach(routes) { route in
                    NavigationLink {
                        TVRouteDirectionsView(data: data, route: route, language: language)
                    } label: {
                        TVRouteCard(route: route, language: language)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(60)
        }
        .scrollClipDisabled()
        .navigationTitle("\(busOperator.name(language)) · \(prefix)")
        .tvScenicBackground()
    }
}

private struct TVRouteCard: View {
    let route: TVBusRoute
    let language: TVLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(route.number)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(operatorNames)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(.horizontal, 26)
    }

    private var operatorNames: String {
        route.operatorIds.flatMap { $0.split(separator: "+").map(String.init) }
            .compactMap { id in TVBusOperator.allCases.first { $0.id == id }?.name(language) }
            .joined(separator: " · ")
    }
}

private struct TVETADisplayRoutesView: View {
    let language: TVLanguage
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TVBusFavorites.storageKey) private var storedRoutes = ""

    private var routes: [TVFavoriteBusRoute] { TVBusFavorites.decode(storedRoutes) }

    var body: some View {
        Group {
            if routes.isEmpty {
                ContentUnavailableView {
                    Label(
                        language.text("No ETA Display Routes", "尚未加入到站顯示路線", "尚未加入到站显示路线"),
                        systemImage: "rectangle.on.rectangle"
                    )
                } description: {
                    Text(language.text(
                        "Choose an operator and route, then add a direction to the ETA Display.",
                        "請選擇營辦商及路線，再將一個方向加入到站顯示。",
                        "请选择运营商及路线，再将一个方向加入到站显示。"
                    ))
                } actions: {
                    Button {
                        dismiss()
                    } label: {
                        Label(
                            language.text("Browse Operators", "瀏覽營辦商", "浏览运营商"),
                            systemImage: "bus.doubledecker.fill"
                        )
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        ForEach(routes) { route in
                            HStack(spacing: 28) {
                                Text(route.number)
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .frame(width: 150, alignment: .leading)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(route.selectedStop(language) ?? route.destination(language))
                                        .font(.title2.bold())
                                    Text(
                                        route.selectedStop(language) == nil
                                            ? language.text("From ", "由 ", "由 ") + route.origin(language)
                                            : language.text("Towards ", "往 ", "往 ") + route.destination(language)
                                    )
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) { remove(route.id) } label: {
                                    Label(
                                        language.text("Remove", "移除", "移除"),
                                        systemImage: "trash"
                                    )
                                }
                            }
                            .padding(.horizontal, 36)
                            .frame(minHeight: 135)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .padding(70)
                    .frame(maxWidth: 1500)
                }
            }
        }
        .navigationTitle(language.text("ETA Display Routes", "到站顯示路線", "到站显示路线"))
        .tvScenicBackground()
    }

    private func remove(_ id: String) {
        storedRoutes = TVBusFavorites.encode(routes.filter { $0.id != id })
    }
}

private struct TVRouteDirectionsView: View {
    let data: TVBusDataStore
    let route: TVBusRoute
    let language: TVLanguage

    private var directions: [TVBusDirection] { data.directions(for: route) }

    var body: some View {
        Group {
            if directions.isEmpty {
                ContentUnavailableView(
                    language.text("No Direction Details", "沒有方向資料", "没有方向数据"),
                    systemImage: "arrow.left.arrow.right",
                    description: Text(language.text(
                        "This route does not currently include usable endpoint information.",
                        "此路線暫時沒有可用的總站資料。",
                        "此路线暂时没有可用的总站数据。"
                    ))
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(language.text(
                            "Choose a direction, then select the stop you want to check.",
                            "選擇行車方向，然後選擇要查看的車站。",
                            "选择行车方向，然后选择要查看的车站。"
                        ))
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(directions) { direction in
                            NavigationLink {
                                TVRouteStopsView(
                                    data: data,
                                    route: route,
                                    direction: direction,
                                    language: language
                                )
                            } label: {
                                HStack(spacing: 28) {
                                    Image(systemName: "arrow.right.circle")
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(sanitizedTVDisplayText(direction.destination.name(language)))
                                            .font(.headline.bold())
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(language.text("From ", "由 ", "由 ") + sanitizedTVDisplayText(direction.origin.name(language)))
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    Text(language.text("Choose Stop", "選擇車站", "选择车站"))
                                        .font(.callout)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .padding(.horizontal, 34)
                                .frame(minHeight: 120)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(70)
                    .frame(maxWidth: 1350)
                }
            }
        }
        .navigationTitle(language.text("Route ", "路線 ", "路线 ") + route.number)
        .tvScenicBackground()
    }
}

private struct TVRouteStopsView: View {
    let data: TVBusDataStore
    let route: TVBusRoute
    let direction: TVBusDirection
    let language: TVLanguage

    @AppStorage(TVBusFavorites.storageKey) private var storedFavorites = ""

    private var stops: [TVBusStopCall] { data.stops(for: direction) }
    private var favorites: [TVFavoriteBusRoute] { TVBusFavorites.decode(storedFavorites) }

    var body: some View {
        Group {
            if stops.isEmpty {
                ContentUnavailableView(
                    language.text("No Stops Available", "沒有可用車站", "没有可用车站"),
                    systemImage: "bus.stop",
                    description: Text(language.text(
                        "Stop information is not available for this direction.",
                        "此方向暫時沒有車站資料。",
                        "此方向暂时没有车站资料。"
                    ))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(stops) { stopCall in
                            let selected = favorites.contains {
                                $0.journeyID == direction.id && $0.selectedStopID == stopCall.stop.id
                            }

                            Button { select(stopCall) } label: {
                                HStack(spacing: 26) {
                                    Text("\(stopCall.journeyStop.sequence)")
                                        .font(.title2.bold())
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .frame(width: 82, alignment: .trailing)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(stopCall.stop.name(language))
                                            .font(.headline)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.7)
                                        if stopCall.journeyStop.stopPickDrop == "1" {
                                            Text(language.text("Alighting only", "只供落客", "只供下客"))
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Label(
                                        selected
                                            ? language.text("Selected", "已選擇", "已选择")
                                            : language.text("Check This Stop", "查看此站", "查看此站"),
                                        systemImage: selected ? "checkmark.circle.fill" : "plus.circle"
                                    )
                                    .font(.callout)
                                }
                                .padding(.horizontal, 32)
                                .frame(minHeight: 100)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(70)
                    .frame(maxWidth: 1350)
                }
            }
        }
        .navigationTitle(
            language.text("Route ", "路線 ", "路线 ")
                + route.number
                + " · "
                + sanitizedTVDisplayText(direction.destination.name(language))
                    .replacingOccurrences(of: "\n", with: " ")
        )
        .tvScenicBackground()
    }

    private func select(_ stopCall: TVBusStopCall) {
        var updated = favorites
        if let index = updated.firstIndex(where: { $0.journeyID == direction.id }) {
            if updated[index].selectedStopID == stopCall.stop.id {
                updated.remove(at: index)
            } else {
                updated[index] = TVFavoriteBusRoute(
                    route: route,
                    direction: direction,
                    stopCall: stopCall
                )
            }
        } else {
            updated.append(TVFavoriteBusRoute(
                route: route,
                direction: direction,
                stopCall: stopCall
            ))
        }
        storedFavorites = TVBusFavorites.encode(updated)
    }
}

private struct TVGreetingMarquee: View {
    let language: TVLanguage
    let userName: String
    let weather: TVCurrentWeather?
    let warnings: [TVWeatherWarning]
    @State private var messageIndex = 0
#if DEBUG
    @AppStorage("tvDebugFestivalPreview") private var festivalPreviewRaw = TVFestivalPreview.live.rawValue
#endif

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let timeGreeting = switch hour {
        case 5..<12:
            language.text("Good morning", "早晨", "早上好")
        case 12..<18:
            language.text("Good afternoon", "晏晝好", "下午好")
        default:
            language.text("Good evening", "夜晚好", "晚上好")
        }
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? timeGreeting : "\(timeGreeting), \(name)"
    }

    private var messages: [String] {
        var result = festivalMessages + [
            language.text("How are you today?", "今天你好嗎？", "今天你好吗？"),
            language.text("Have a pleasant journey.", "祝你旅途愉快。", "祝你旅途愉快。")
        ]
        let warningKinds = Set(warnings.map(\.kind))
        let icon = weather?.icon
        let temperature = weather?.temperature
        let isRainy = icon.map { (60...65).contains($0) } == true || (weather?.rainfall ?? 0) > 0
        let isStormy = icon == 64 || warningKinds.contains("WTS")
        let isWindy = icon.map { (80...84).contains($0) } == true
            || warningKinds.contains("WMSGNL")
            || warningKinds.contains("WTCSGNL")
        let isHot = icon == 85 || (temperature ?? 0) >= 30 || warningKinds.contains("WHOT")
        let isHighUV = (weather?.uvIndex ?? 0) >= 6
        let isCold = icon.map { (90...93).contains($0) } == true
            || (temperature.map { $0 <= 18 } ?? false)
            || warningKinds.contains("WCOLD")

        if isRainy {
            result.append(language.text(
                "Remember to bring an umbrella.",
                "記得帶雨傘。",
                "记得带雨伞。"
            ))
        }
        if isHot {
            result.append(language.text(
                "Stay hydrated and drink more water.",
                "天氣炎熱，記得多喝水。",
                "天气炎热，记得多喝水。"
            ))
        }
        if isHighUV {
            result.append(language.text(
                "UV is high. Use sun protection outdoors.",
                "紫外線指數偏高，外出記得做好防曬。",
                "紫外线指数偏高，外出记得做好防晒。"
            ))
        }
        if isCold {
            result.append(language.text(
                "Keep warm and bring a jacket.",
                "天氣清涼，記得帶外套。",
                "天气清凉，记得带外套。"
            ))
        }
        if isStormy {
            result.append(language.text(
                "Thunderstorms are nearby. Take care outdoors.",
                "附近有雷暴，戶外活動請小心。",
                "附近有雷暴，户外活动请小心。"
            ))
        } else if isWindy {
            result.append(language.text(
                "It is windy. Take care outdoors.",
                "風勢較大，外出請小心。",
                "风势较大，外出请小心。"
            ))
        }
        return result
    }

    private var festivalMessages: [String] {
#if DEBUG
        let preview = TVFestivalPreview(rawValue: festivalPreviewRaw) ?? .live
        if let greeting = preview.greeting(language) {
            return [greeting]
        }
#endif
        let now = Date.now
        var result: [String] = []
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        let solar = gregorian.dateComponents([.month, .day], from: now)

        switch (solar.month, solar.day) {
        case (1, 1), (12, 31):
            result.append(language.text("Happy New Year!", "新年快樂！", "新年快乐！"))
        case (5, 1):
            result.append(language.text("Happy Labour Day!", "勞動節快樂！", "劳动节快乐！"))
        case (7, 1):
            result.append(language.text(
                "Happy HKSAR Establishment Day!",
                "香港特別行政區成立紀念日快樂！",
                "香港特别行政区成立纪念日快乐！"
            ))
        case (10, 1):
            result.append(language.text("Happy National Day!", "國慶日快樂！", "国庆日快乐！"))
        case (12, 24), (12, 25), (12, 26):
            result.append(language.text("Merry Christmas!", "聖誕快樂！", "圣诞快乐！"))
        default:
            break
        }

        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = .current
        let lunar = chinese.dateComponents([.month, .day, .isLeapMonth], from: now)
        if lunar.isLeapMonth != true, let month = lunar.month, let day = lunar.day {
            switch (month, day) {
            case (1, 1...3):
                result.append(language.text(
                    "Happy Lunar New Year!",
                    "農曆新年快樂！",
                    "农历新年快乐！"
                ))
            case (1, 15):
                result.append(language.text(
                    "Happy Lantern Festival!",
                    "元宵節快樂！",
                    "元宵节快乐！"
                ))
            case (4, 8):
                result.append(language.text(
                    "Happy Buddha's Birthday!",
                    "佛誕吉祥！",
                    "佛诞吉祥！"
                ))
            case (5, 5):
                result.append(language.text(
                    "Happy Dragon Boat Festival!",
                    "端午節快樂！",
                    "端午节快乐！"
                ))
            case (8, 15):
                result.append(language.text(
                    "Happy Mid-Autumn Festival!",
                    "中秋節快樂！",
                    "中秋节快乐！"
                ))
            case (9, 9):
                result.append(language.text(
                    "Happy Chung Yeung Festival!",
                    "重陽節快樂！",
                    "重阳节快乐！"
                ))
            default:
                break
            }
        }
        return result
    }

    private var message: String {
        let safeIndex = min(messageIndex, max(messages.count - 1, 0))
        return "\(greeting)  ·  \(messages[safeIndex])"
    }

    var body: some View {
        Text(message)
            .font(.headline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .id(messageIndex)
            .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .task(id: messages) {
            messageIndex = 0
            guard messages.count > 1 else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(12))
                } catch {
                    break
                }
                withAnimation(.easeInOut(duration: 0.6)) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
}

private struct TVSettingsView: View {
    @Binding var language: TVLanguage
    @AppStorage("tvUserName") private var userName = ""
    @AppStorage("tvBackgroundSelection") private var backgroundSelection = TVBackgroundPreview.automatic

    var body: some View {
        List {
            HStack(spacing: 20) {
                Image(systemName: "person.fill").frame(width: 44)
                Text(language.text("Name", "稱呼", "称呼"))
                    .foregroundStyle(.primary)
                Spacer()
                TextField(language.text("Optional", "選填", "选填"), text: $userName)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 420)
            }
            .font(.title3)
            .padding(.vertical, 12)

            NavigationLink {
                TVLanguageSettings(language: $language)
            } label: {
                settingsRow(language.text("Language", "語言", "语言"), value: language.title, symbol: "globe")
            }

            NavigationLink {
                TVOperatorSettings(language: language)
            } label: {
                settingsRow(
                    language.text("Bus Operators", "巴士營辦商", "巴士运营商"),
                    value: language.text("All by default", "預設全部", "默认全部"),
                    symbol: "bus.doubledecker.fill"
                )
            }

            NavigationLink {
                TVBackgroundPreviewSettings(language: language, preview: $backgroundSelection)
            } label: {
                settingsRow(
                    language.text("Background", "背景", "背景"),
                    value: backgroundSelection.name(language),
                    symbol: "photo.on.rectangle"
                )
            }

#if DEBUG
            NavigationLink {
                TVDeveloperTestingSettings(language: language)
            } label: {
                settingsRow(
                    language.text("Developer Testing", "開發者測試", "开发者测试"),
                    value: language.text("3 tools", "3 項工具", "3 项工具"),
                    symbol: "hammer.fill"
                )
            }
#endif

            NavigationLink {
                TVInformationPage(
                    title: language.text("Disclaimer", "免責聲明", "免责声明"),
                    symbol: "exclamationmark.shield",
                    paragraphs: disclaimer
                )
            } label: {
                settingsRow(language.text("Disclaimer", "免責聲明", "免责声明"), symbol: "exclamationmark.shield")
            }

            NavigationLink {
                TVInformationPage(
                    title: language.text("Data Sources", "資料來源", "数据来源"),
                    symbol: "externaldrive.connected.to.line.below",
                    paragraphs: dataSources
                )
            } label: {
                settingsRow(language.text("Data Sources", "資料來源", "数据来源"), symbol: "externaldrive.connected.to.line.below")
            }

            NavigationLink {
                TVInformationPage(
                    title: language.text("About HK Way", "關於喂!香港", "关于喂!香港"),
                    symbol: "info.circle",
                    paragraphs: aboutHKWay
                )
            } label: {
                settingsRow(language.text("About HK Way", "關於喂!香港", "关于喂!香港"), symbol: "info.circle")
            }
        }
        .navigationTitle(language.text("Settings", "設定", "设置"))
        .tvScenicBackground()
    }

    private func settingsRow(_ title: String, value: String? = nil, symbol: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: symbol).frame(width: 44)
            Text(title).foregroundStyle(.primary)
            Spacer()
            if let value { Text(value).foregroundStyle(.secondary) }
        }
        .font(.title3)
        .padding(.vertical, 12)
    }

    private var disclaimer: [String] {
        [language.text(
            "HK Way provides transport information for reference only. Arrival times may change because of traffic, operations, weather, or provider availability. Confirm the destination and service before boarding.",
            "喂!香港提供的交通資訊只供參考。到站時間可能因交通、營運、天氣或資料供應情況而改變。上車前請確認目的地及班次。",
            "喂!香港提供的交通信息仅供参考。到站时间可能因交通、运营、天气或数据供应情况而改变。上车前请确认目的地及班次。"
        )]
    }

    private var dataSources: [String] {
        [
            language.text("Public transport data: DATA.GOV.HK and participating transport operators.", "公共交通資料：DATA.GOV.HK 及各參與交通營辦商。", "公共交通数据：DATA.GOV.HK 及各参与交通运营商。"),
            language.text("Current weather: Hong Kong Observatory Open Data API.", "即時天氣：香港天文台開放數據 API。", "实时天气：香港天文台开放数据 API。"),
            language.text("Background photography: Ken Wong.", "背景相片：Ken Wong。", "背景照片：Ken Wong。"),
            language.text("HK Way is independently operated and is not affiliated with the Hong Kong Government or transport operators.", "喂!香港為獨立營運，與香港政府或交通營辦商並無關聯。", "喂!香港为独立运营，与香港政府或交通运营商并无关联。")
        ]
    }

    private var aboutHKWay: [String] {
        [
            language.text(
                "All HK Way features on Apple TV are free to use. No account or additional setup is required.",
                "Apple TV 版喂!香港的所有功能均可免費使用，毋須帳戶或額外設定。",
                "Apple TV 版喂!香港的所有功能均可免费使用，无需帐户或额外设置。"
            ),
            language.text(
                "Use Routes to choose a bus operator, route, direction, and stop. Saved selections appear on Home with live arrival information.",
                "你可在「路線」選擇巴士營辦商、路線、方向及車站；已儲存的選擇會在「主頁」顯示即時到站資訊。",
                "你可在“路线”选择巴士运营商、路线、方向及车站；已保存的选择会在“主页”显示实时到站信息。"
            )
        ]
    }
}

#if DEBUG
private struct TVDeveloperTestingSettings: View {
    let language: TVLanguage
    @AppStorage("tvDebugWeatherWarningPreview") private var warningPreviewRaw = TVWeatherWarningPreview.live.rawValue
    @AppStorage("tvDebugTrafficNewsPreview") private var showsTrafficNewsPreview = false
    @AppStorage("tvDebugFestivalPreview") private var festivalPreviewRaw = TVFestivalPreview.live.rawValue

    var body: some View {
        List {
            NavigationLink {
                TVWeatherWarningPreviewSettings(language: language, selection: $warningPreviewRaw)
            } label: {
                settingsRow(
                    language.text("Weather Warning Preview", "天氣警告預覽", "天气警告预览"),
                    value: (TVWeatherWarningPreview(rawValue: warningPreviewRaw) ?? .live).title(language),
                    symbol: "exclamationmark.triangle.fill"
                )
            }

            NavigationLink {
                TVFestivalPreviewSettings(language: language, selection: $festivalPreviewRaw)
            } label: {
                settingsRow(
                    language.text("Festival Greeting Preview", "節日祝賀預覽", "节日祝贺预览"),
                    value: (TVFestivalPreview(rawValue: festivalPreviewRaw) ?? .live).title(language),
                    symbol: "party.popper.fill"
                )
            }

            Toggle(isOn: $showsTrafficNewsPreview) {
                settingsRow(
                    language.text("Sample Traffic News", "模擬交通消息", "模拟交通消息"),
                    value: language.text("3 rotating notices", "3 則輪播消息", "3 则轮播消息"),
                    symbol: "newspaper.fill"
                )
            }
        }
        .navigationTitle(language.text("Developer Testing", "開發者測試", "开发者测试"))
        .tvScenicBackground()
    }

    private func settingsRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: symbol).frame(width: 44)
            Text(title).foregroundStyle(.primary)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.title3)
        .padding(.vertical, 12)
    }
}

private struct TVFestivalPreviewSettings: View {
    let language: TVLanguage
    @Binding var selection: String

    var body: some View {
        List(TVFestivalPreview.allCases) { preview in
            Button {
                selection = preview.rawValue
            } label: {
                HStack(spacing: 22) {
                    Image(systemName: preview == .live ? "calendar" : "party.popper.fill")
                        .font(.title3)
                        .frame(width: 70, alignment: .leading)
                    Text(preview.title(language))
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection == preview.rawValue {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.title3)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(language.text("Festival Greeting Preview", "節日祝賀預覽", "节日祝贺预览"))
        .tvScenicBackground()
    }
}

private struct TVWeatherWarningPreviewSettings: View {
    let language: TVLanguage
    @Binding var selection: String

    var body: some View {
        List(TVWeatherWarningPreview.allCases) { preview in
            Button {
                selection = preview.rawValue
            } label: {
                HStack(spacing: 22) {
                    if let warningCode = preview.warningCode {
                        Text(warningCode.code.replacingOccurrences(of: "TC", with: "T"))
                            .font(.headline.bold())
                            .frame(width: 100, alignment: .leading)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title3)
                            .frame(width: 100, alignment: .leading)
                    }
                    Text(preview.title(language))
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection == preview.rawValue {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.title3)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(language.text("Weather Warning Preview", "天氣警告預覽", "天气警告预览"))
        .tvScenicBackground()
    }
}
#endif

private struct TVBackgroundPreviewSettings: View {
    let language: TVLanguage
    @Binding var preview: TVBackgroundPreview

    var body: some View {
        List {
            Button { preview = .automatic } label: {
                HStack(spacing: 24) {
                    Image(systemName: "wand.and.stars")
                        .font(.title2)
                        .frame(width: 160, height: 90)
                    Text(TVBackgroundPreview.automatic.name(language)).foregroundStyle(.primary)
                    Spacer()
                    if preview == .automatic {
                        Image(systemName: "checkmark").foregroundStyle(.primary)
                    }
                }
                .font(.title3)
            }
            .buttonStyle(.plain)

            ForEach(TVBackgroundCategory.allCases) { category in
                NavigationLink {
                    TVBackgroundCategorySettings(
                        language: language,
                        category: category,
                        preview: $preview
                    )
                } label: {
                    HStack(spacing: 24) {
                        if let imageName = category.options.first?.imageName {
                            backgroundThumbnail(imageName)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.name(language)).foregroundStyle(.primary)
                            Text(category.options.count, format: .number)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if category.options.contains(preview) {
                            Image(systemName: "checkmark").foregroundStyle(.primary)
                        }
                    }
                    .font(.title3)
                }
            }
        }
        .navigationTitle(language.text("Background", "背景", "背景"))
        .tvScenicBackground()
    }

    private func backgroundThumbnail(_ imageName: String) -> some View {
        Image(imageName, bundle: .main)
            .resizable()
            .scaledToFill()
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TVBackgroundCategorySettings: View {
    let language: TVLanguage
    let category: TVBackgroundCategory
    @Binding var preview: TVBackgroundPreview

    var body: some View {
        List(category.options) { option in
            Button { preview = option } label: {
                HStack(spacing: 24) {
                    if let imageName = option.imageName {
                        Image(imageName, bundle: .main)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Text(option.name(language)).foregroundStyle(.primary)
                    Spacer()
                    if option == preview {
                        Image(systemName: "checkmark").foregroundStyle(.primary)
                    }
                }
                .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(category.name(language))
        .tvScenicBackground()
    }
}

private struct TVLanguageSettings: View {
    @Binding var language: TVLanguage

    var body: some View {
        List(TVLanguage.allCases) { option in
            Button { language = option } label: {
                HStack {
                    Text(option.title).foregroundStyle(.primary)
                    Spacer()
                    if option == language { Image(systemName: "checkmark").foregroundStyle(.primary) }
                }
                .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(language.text("Language", "語言", "语言"))
        .tvScenicBackground()
    }
}

private struct TVOperatorSettings: View {
    let language: TVLanguage
    @AppStorage(TVOperatorSelection.storageKey) private var storedSelection = ""

    private var selectedIDs: Set<String> { TVOperatorSelection.ids(from: storedSelection) }

    var body: some View {
        List {
            Button { storedSelection = "" } label: {
                selectionRow(language.text("All Operators", "所有營辦商", "所有运营商"), selected: selectedIDs.isEmpty)
            }
            .buttonStyle(.plain)

            ForEach(TVBusOperator.allCases) { busOperator in
                Button { toggle(busOperator.id) } label: {
                    selectionRow(busOperator.name(language), selected: selectedIDs.contains(busOperator.id))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(language.text("Bus Operators", "巴士營辦商", "巴士运营商"))
        .tvScenicBackground()
    }

    private func selectionRow(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(.primary)
            Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(.primary) }
        }
        .font(.title3)
        .padding(.vertical, 8)
    }

    private func toggle(_ id: String) {
        var ids = selectedIDs
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        storedSelection = TVOperatorSelection.value(from: ids)
    }
}

private struct TVInformationPage: View {
    let title: String
    let symbol: String
    let paragraphs: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: symbol).font(.system(size: 64))
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph).font(.title2).lineSpacing(8)
                }
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(70)
        }
        .navigationTitle(title)
        .tvScenicBackground()
    }
}

private struct TVBackgroundImageNameKey: EnvironmentKey {
    static let defaultValue = "HKPersonalSunny01"
}

private struct TVViewportSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 1920, height: 1080)
}

private extension EnvironmentValues {
    var tvBackgroundImageName: String {
        get { self[TVBackgroundImageNameKey.self] }
        set { self[TVBackgroundImageNameKey.self] = newValue }
    }

    var tvViewportSize: CGSize {
        get { self[TVViewportSizeKey.self] }
        set { self[TVViewportSizeKey.self] = newValue }
    }
}

private struct TVScenicBackgroundModifier: ViewModifier {
    @Environment(\.tvBackgroundImageName) private var imageName
    @Environment(\.tvViewportSize) private var viewportSize

    func body(content: Content) -> some View {
        content.background {
            Image(imageName, bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: viewportSize.width, height: viewportSize.height)
                .clipped()
                .overlay(.black.opacity(0.48))
                .id(imageName)
                .transition(.opacity)
                .ignoresSafeArea()
        }
    }
}

private extension View {
    func tvScenicBackground() -> some View {
        modifier(TVScenicBackgroundModifier())
    }
}
