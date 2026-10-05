import SwiftUI

struct IPadDashboardView: View {
    @Environment(\.transitLanguage) private var language
    @State private var weather = IPadWeatherStore()
    @State private var traffic = IPadTrafficStore()

    var body: some View {
        GeometryReader { proxy in
            let usesCompactLayout = proxy.size.width < 1100
            let horizontalPadding: CGFloat = usesCompactLayout ? 24 : 32
            let availableWidth = max(0, proxy.size.width - (horizontalPadding * 2))
            let contentWidth = min(usesCompactLayout ? 720 : 1400, availableWidth)
            let columnWidth = max(0, (contentWidth - 20) / 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .frame(width: contentWidth)

                    if usesCompactLayout {
                        VStack(spacing: 20) {
                            weatherCard
                            trafficCard
                            departuresCard
                        }
                        .frame(width: contentWidth)
                    } else {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(spacing: 20) {
                                weatherCard
                                trafficCard
                            }
                            .frame(width: columnWidth)
                            .frame(maxHeight: .infinity)

                            departuresCard
                                .frame(width: columnWidth)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(width: contentWidth)
                        .frame(
                            minHeight: max(
                                510,
                                proxy.size.height - 150 - topTabClearance - reservedAdHeight
                            )
                        )
                    }
                }
                .padding(.top, 24 + topTabClearance)
                .padding(.bottom, 24)
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background {
            Image(weather.backgroundImageName)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.42), .black.opacity(0.18), .black.opacity(0.34)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()
                .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .task {
            async let weatherRefresh: Void = weather.refresh()
            async let trafficRefresh: Void = traffic.refresh(language: language)
            _ = await (weatherRefresh, trafficRefresh)
        }
        .refreshable {
            await weather.refresh()
            await traffic.refresh(language: language)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                greetingHeader
                Spacer(minLength: 20)
                dateHeader
            }

            VStack(alignment: .leading, spacing: 8) {
                greetingHeader
                dateHeader
            }
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(language == .english ? "HK Way" : "喂!香港")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(greeting)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var dateHeader: some View {
        Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
            .font(.title2)
            .foregroundStyle(.white.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var reservedAdHeight: CGFloat {
        0
    }

    private var topTabClearance: CGFloat { 64 }

    private var weatherCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                Label(text("Weather", "天氣", "天气"), systemImage: "cloud.sun.fill")
                    .font(.title2.bold())

                if let report = weather.report {
                    HStack(spacing: 18) {
                        Image(systemName: report.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 48))
                        VStack(alignment: .leading) {
                            Text("\(Int(report.temperature.rounded()))°")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text(report.condition(language))
                                .font(.headline)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 22) {
                            weatherMetrics(report)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            weatherMetrics(report)
                        }
                    }

                    if let uv = report.uvIndex, uv >= 6 {
                        Label(
                            text(
                                "UV is high. Use sun protection outdoors.",
                                "紫外線指數偏高，外出記得做好防曬。",
                                "紫外线指数偏高，外出记得做好防晒。"
                            ),
                            systemImage: "sun.max.trianglebadge.exclamationmark.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    }
                } else if weather.isLoading {
                    ProgressView()
                } else {
                    Label(text("Weather unavailable", "未能取得天氣資料", "未能取得天气资料"), systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var departuresCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                Label(text("Departures", "到站時間", "到站时间"), systemImage: "clock.fill")
                    .font(.title2.bold())
                Text(text(
                    "Your saved routes and stops, together in one place.",
                    "集中查看已收藏的路線及車站。",
                    "集中查看已收藏的路线及车站。"
                ))
                .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                NavigationLink {
                    RouteFavoritesView()
                } label: {
                    Label(text("Open Favorites", "開啟收藏", "打开收藏"), systemImage: "bookmark.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(minHeight: 510)
    }

    private var trafficCard: some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                Label(text("Traffic News", "交通消息", "交通消息"), systemImage: "car.fill")
                    .font(.title2.bold())
                if let notice = traffic.notices.first {
                    Text(notice.heading)
                        .font(.headline)
                        .lineLimit(2)
                    Text(notice.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    if traffic.notices.count > 1 {
                        Text("1/\(traffic.notices.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                } else if traffic.isLoading {
                    ProgressView()
                } else {
                    Text(text("No special traffic notices", "暫無特別交通消息", "暂无特别交通消息"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func dashboardCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, minHeight: 245, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func metric(_ symbol: String, _ value: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func weatherMetrics(_ report: IPadWeatherReport) -> some View {
        metric("humidity.fill", "\(text("Humidity", "濕度", "湿度")) \(Int(report.humidity.rounded()))%")
        metric("drop.fill", "\(text("Rain", "雨量", "雨量")) \(Int(report.rainfall.rounded())) mm")
        if let uv = report.uvIndex {
            metric("sun.max.fill", "\(text("UV", "紫外線", "紫外线")) \(Int(uv.rounded()))")
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return switch hour {
        case 5..<12: text("Good morning · Where would you like to go?", "早晨 · 今天想去哪裡？", "早上好 · 今天想去哪里？")
        case 12..<18: text("Good afternoon · Where would you like to go?", "午安 · 今天想去哪裡？", "下午好 · 今天想去哪里？")
        default: text("Good evening · Where would you like to go?", "晚上好 · 今天想去哪裡？", "晚上好 · 今天想去哪里？")
        }
    }

    private func text(_ english: String, _ traditional: String, _ simplified: String) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }
}

private struct IPadTrafficNotice {
    let heading: String
    let content: String
    let announcedAt: Date
}

@MainActor
@Observable
private final class IPadTrafficStore {
    private(set) var notices: [IPadTrafficNotice] = []
    private(set) var isLoading = false

    func refresh(language: TransitLanguage) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let path = language == .english ? "en" : (language == .traditionalChinese ? "tc" : "sc")
        guard let url = URL(string: "https://www.td.gov.hk/\(path)/special_news/trafficnews.xml") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let cutoff = Date.now.addingTimeInterval(-3 * 60 * 60)
            notices = IPadTrafficParser(language: language).parse(data)
                .filter { $0.announcedAt >= cutoff }
                .sorted { $0.announcedAt > $1.announcedAt }
                .prefix(3)
                .map { $0 }
        } catch {}
    }
}

private final class IPadTrafficParser: NSObject, XMLParserDelegate {
    private let language: TransitLanguage
    private var text = ""
    private var fields: [String: String] = [:]
    private var results: [IPadTrafficNotice] = []

    init(language: TransitLanguage) { self.language = language }

    func parse(_ data: Data) -> [IPadTrafficNotice] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return results
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        text = ""
        if elementName == "message" { fields = [:] }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "message" {
            let suffix = language == .english ? "EN" : "CN"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = formatter.date(from: fields["ANNOUNCEMENT_DATE"] ?? ""),
               let content = fields["CONTENT_\(suffix)"], !content.isEmpty {
                results.append(IPadTrafficNotice(
                    heading: fields["INCIDENT_HEADING_\(suffix)"] ?? "",
                    content: content,
                    announcedAt: date
                ))
            }
        } else if !value.isEmpty {
            fields[elementName] = value
        }
        text = ""
    }
}

@MainActor
@Observable
private final class IPadWeatherStore {
    private(set) var report: IPadWeatherReport?
    private(set) var isLoading = false
    private(set) var backgroundImageName = IPadBackgroundScene.current(daytime: .sunny).randomImage
    private var selectedScene = IPadBackgroundScene.current(daytime: .sunny)

    func refresh() async {
        guard !isLoading,
              let url = URL(string: "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=rhrread&lang=en") else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let source = try JSONDecoder().decode(IPadWeatherResponse.self, from: data)
            guard let icon = source.icon.first else { return }
            report = IPadWeatherReport(
                temperature: source.temperature.preferred("Hong Kong Observatory") ?? 0,
                humidity: source.humidity.preferred("Hong Kong Observatory") ?? 0,
                rainfall: source.rainfall?.data.map { $0.max ?? $0.min ?? 0 }.max() ?? 0,
                uvIndex: source.uvindex?.data.first?.value,
                icon: icon
            )
            selectBackground(for: icon)
        } catch {}
    }

    private func selectBackground(for icon: Int) {
        let daytime: IPadBackgroundScene = switch icon {
        case 50...53, 70, 75, 76: .sunny
        case 62...65: .rainy
        default: .cloudy
        }
        let scene = IPadBackgroundScene.current(daytime: daytime)
        guard scene != selectedScene else { return }
        selectedScene = scene
        backgroundImageName = scene.randomImage
    }
}

private enum IPadBackgroundScene {
    case sunny, cloudy, rainy, sunset, night

    static func current(daytime: Self) -> Self {
        switch Calendar.current.component(.hour, from: .now) {
        case 6..<17: daytime
        case 17..<19: .sunset
        default: .night
        }
    }

    var randomImage: String {
        let images = switch self {
        case .sunny: ["HKPersonalSunny01", "HKPersonalSunny03", "HKPersonalSunny04", "HKPersonalSunny05", "HKPersonalSunny06", "HKPersonalSunny07", "HKPersonalSunny11", "HKPersonalSunny13"]
        case .cloudy: ["HKPersonalCloudy01", "HKPersonalCloudy02", "HKPersonalCloudy03"]
        case .rainy: ["HKPersonalRainy01", "HKPersonalRainy02"]
        case .sunset: ["HKPersonalSunset01", "HKPersonalSunset02", "HKPersonalSunset03"]
        case .night: ["HKPersonalNight01"]
        }
        return images.randomElement() ?? "HKPersonalSunny01"
    }
}

private struct IPadWeatherReport {
    let temperature: Double
    let humidity: Double
    let rainfall: Double
    let uvIndex: Double?
    let icon: Int

    var symbol: String {
        switch icon {
        case 50...52, 70, 75, 76: "sun.max.fill"
        case 60...63, 65: "cloud.rain.fill"
        case 64: "cloud.bolt.rain.fill"
        case 80...84: "wind"
        default: "cloud.fill"
        }
    }

    func condition(_ language: TransitLanguage) -> String {
        let values: (String, String, String) = switch icon {
        case 50: ("Sunny", "天晴", "晴朗")
        case 51...52: ("Sunny intervals", "間有陽光", "间有阳光")
        case 53: ("Cloudy", "多雲", "多云")
        case 60...65: ("Rain", "有雨", "有雨")
        case 80...84: ("Windy", "大風", "大风")
        case 85: ("Hot", "炎熱", "炎热")
        default: ("Current conditions", "現時天氣", "当前天气")
        }
        return switch language {
        case .english: values.0
        case .traditionalChinese: values.1
        case .simplifiedChinese: values.2
        }
    }
}

private struct IPadWeatherResponse: Decodable {
    let icon: [Int]
    let temperature: IPadMeasurementGroup
    let humidity: IPadMeasurementGroup
    let rainfall: IPadRainfallGroup?
    let uvindex: IPadMeasurementGroup?
}

private struct IPadMeasurementGroup: Decodable {
    let data: [IPadMeasurement]
    func preferred(_ place: String) -> Double? {
        data.first(where: { $0.place == place })?.value ?? data.first?.value
    }
}

private struct IPadMeasurement: Decodable {
    let place: String
    let value: Double
}

private struct IPadRainfallGroup: Decodable {
    let data: [IPadRainfall]
}

private struct IPadRainfall: Decodable {
    let max: Double?
    let min: Double?
}
