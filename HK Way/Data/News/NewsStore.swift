import Foundation
import Observation

struct NewsWeatherSnapshot: Sendable, Equatable {
    let temperature: Double?
    let humidity: Double?
    let rainfall: Double?
    let ultravioletIndex: Double?
    let icon: Int

    var symbolName: String {
        Self.symbolName(for: icon)
    }

    static func symbolName(for icon: Int) -> String {
        switch icon {
        case 50...52, 70, 75, 76: "sun.max.fill"
        case 60...63, 65: "cloud.rain.fill"
        case 64: "cloud.bolt.rain.fill"
        case 80...84: "wind"
        case 85: "thermometer.sun.fill"
        default: "cloud.fill"
        }
    }

    func condition(language: TransitLanguage) -> String {
        switch icon {
        case 50: language.newsText("Sunny", "天晴", "晴朗")
        case 51: language.newsText("Sunny periods", "短暫陽光", "短暂阳光")
        case 52: language.newsText("Sunny intervals", "間有陽光", "间有阳光")
        case 53: language.newsText("Cloudy", "多雲", "多云")
        case 54: language.newsText("Overcast", "密雲", "陰天")
        case 60: language.newsText("Cloudy with rain", "多雲有雨", "多云有雨")
        case 61: language.newsText("Light rain", "微雨", "小雨")
        case 62: language.newsText("Rain", "有雨", "有雨")
        case 63: language.newsText("Heavy rain", "大雨", "大雨")
        case 64: language.newsText("Thunderstorms", "雷暴", "雷暴")
        case 65: language.newsText("Showers", "驟雨", "陣雨")
        case 70: language.newsText("Fine", "天色良好", "天氣良好")
        case 71...77: language.newsText("Dry", "乾燥", "乾燥")
        case 80...84: language.newsText("Windy", "大風", "大風")
        case 85: language.newsText("Hot", "炎熱", "炎熱")
        case 90...93: language.newsText("Cool", "清涼", "清涼")
        default: language.newsText("Current conditions", "現時天氣", "目前天氣")
        }
    }
}

struct NewsWeatherAlert: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let kind: String

    var symbolName: String {
        switch kind {
        case "WMSGNL": "wind"
        case "WRAIN": "cloud.heavyrain.fill"
        case "WTCSGNL": "hurricane"
        case "WTS": "cloud.bolt.rain.fill"
        case "WHOT": "thermometer.sun.fill"
        case "WCOLD", "WFROST": "thermometer.snowflake"
        case "WFIRE": "flame.fill"
        default: "exclamationmark.triangle.fill"
        }
    }
}

struct NewsWeatherTip: Identifiable, Sendable, Equatable {
    let id: String
    let detail: String
}

struct NewsDailyForecast: Identifiable, Sendable, Equatable {
    let date: Date
    let icon: Int
    let minimumTemperature: Double?
    let maximumTemperature: Double?
    let summary: String

    var id: Date { date }

    var symbolName: String { NewsWeatherSnapshot.symbolName(for: icon) }
}

struct NewsForecastUpdate: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let detail: String
}

struct NewsTrafficNotice: Identifiable, Sendable, Equatable {
    let id: String
    let content: String
    let announcedAt: Date?
}


struct NewsTrafficIncident: Identifiable, Sendable, Equatable {
    let id: String
    let heading: String
    let content: String
    let announcedAt: Date?
}

@MainActor
@Observable
final class NewsStore {
    private(set) var weather: NewsWeatherSnapshot?
    private(set) var weatherAlerts: [NewsWeatherAlert] = []
    private(set) var weatherTips: [NewsWeatherTip] = []
    private(set) var dailyForecasts: [NewsDailyForecast] = []
    private(set) var forecastUpdates: [NewsForecastUpdate] = []
    private(set) var trafficNotices: [NewsTrafficNotice] = []
    private(set) var trafficIncidents: [NewsTrafficIncident] = []
    private(set) var isLoading = false
    private(set) var hasWeatherError = false
    private(set) var hasTrafficError = false
    private(set) var hasTrafficIncidentError = false

    func refresh(language: TransitLanguage) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let weatherTask: Void = refreshWeather(language: language)
        async let trafficTask: Void = refreshTraffic(language: language)
        _ = await (weatherTask, trafficTask)
    }

    private func refreshWeather(language: TransitLanguage) async {
        let languageCode = language.newsLanguageCode
        do {
            async let currentData = fetch(
                "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=rhrread&lang=\(languageCode)"
            )
            async let warningData = fetch(
                "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=warnsum&lang=\(languageCode)"
            )
            async let tipData = fetch(
                "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=swt&lang=\(languageCode)"
            )
            async let forecastData = fetch(
                "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=fnd&lang=\(languageCode)"
            )
            async let localForecastData = fetch(
                "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=flw&lang=\(languageCode)"
            )

            let (current, warnings, tips, forecast, localForecastPayloadData) = try await (
                currentData, warningData, tipData, forecastData, localForecastData
            )
            let report = try JSONDecoder().decode(NewsCurrentWeatherPayload.self, from: current)
            weather = NewsWeatherSnapshot(
                temperature: report.temperature.preferredValue,
                humidity: report.humidity.preferredValue,
                rainfall: report.rainfall?.data.map(\.maximumValue).max(),
                ultravioletIndex: report.uvindex?.data.first?.value,
                icon: report.icon.first ?? 53
            )

            let warningRecords = try JSONDecoder().decode(
                [String: NewsWarningPayload].self,
                from: warnings
            )
            weatherAlerts = warningRecords.compactMap { kind, record in
                guard record.actionCode != "CANCEL" else { return nil }
                return NewsWeatherAlert(id: kind, name: record.name, kind: kind)
            }
            .sorted { $0.name < $1.name }

            let tipReport = try JSONDecoder().decode(NewsTipPayload.self, from: tips)
            weatherTips = tipReport.swt.enumerated().map { index, tip in
                NewsWeatherTip(id: "tip-\(index)-\(tip.desc)", detail: tip.desc)
            }

            let forecastReport = try JSONDecoder().decode(NewsForecastPayload.self, from: forecast)
            dailyForecasts = forecastReport.weatherForecast.prefix(7).compactMap { day in
                guard let date = Self.forecastDateFormatter.date(from: day.forecastDate) else { return nil }
                return NewsDailyForecast(
                    date: date,
                    icon: day.ForecastIcon,
                    minimumTemperature: day.forecastMintemp?.value,
                    maximumTemperature: day.forecastMaxtemp?.value,
                    summary: day.forecastWeather
                )
            }

            let localForecast = try JSONDecoder().decode(
                NewsLocalForecastPayload.self,
                from: localForecastPayloadData
            )
            forecastUpdates = [
                NewsForecastUpdate(
                    id: "local-forecast",
                    title: language.newsText("Local Forecast", "本港地區天氣預報", "本港地区天气预报"),
                    detail: localForecast.forecastDesc
                ),
                NewsForecastUpdate(
                    id: "outlook",
                    title: language.newsText("Outlook", "展望", "展望"),
                    detail: localForecast.outlook
                )
            ].filter { !$0.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            hasWeatherError = false
        } catch {
            hasWeatherError = true
        }
    }

    private static let forecastDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private func refreshTraffic(language: TransitLanguage) async {
        async let incidentsResult: Void = refreshTrafficIncidents(language: language)
        async let specialResult: Void = refreshSpecialTrafficNotices(language: language)
        _ = await (incidentsResult, specialResult)
    }

    private func refreshTrafficIncidents(language: TransitLanguage) async {
        do {
            let data = try await fetch(
                "https://www.td.gov.hk/\(language.newsLanguageCode)/special_news/trafficnews.xml"
            )
            trafficIncidents = try NewsTrafficIncidentParser(language: language)
                .parse(data)
                .sorted { left, right in
                    (left.announcedAt ?? .distantPast) > (right.announcedAt ?? .distantPast)
                }
            hasTrafficIncidentError = false
        } catch {
            hasTrafficIncidentError = true
        }
    }

    private func refreshSpecialTrafficNotices(language: TransitLanguage) async {
        do {
            let data = try await fetch(
                "https://resource.data.one.gov.hk/td/\(language.newsLanguageCode)/specialtrafficnews.xml"
            )
            trafficNotices = try NewsTrafficParser(language: language)
                .parse(data)
                .sorted { left, right in
                    (left.announcedAt ?? .distantPast) > (right.announcedAt ?? .distantPast)
                }
            hasTrafficError = false
        } catch {
            hasTrafficError = true
        }
    }

    private func fetch(_ address: String) async throws -> Data {
        guard let url = URL(string: address) else { throw URLError(.badURL) }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.setValue("HK Way", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

private final class NewsTrafficIncidentParser: NSObject, XMLParserDelegate {
    private let language: TransitLanguage
    private var currentText = ""
    private var fields: [String: String] = [:]
    private var results: [NewsTrafficIncident] = []

    init(language: TransitLanguage) {
        self.language = language
    }

    func parse(_ data: Data) throws -> [NewsTrafficIncident] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return results
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        if elementName == "message" { fields = [:] }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "message" {
            let suffix = language == .english ? "EN" : "CN"
            let heading = fields["INCIDENT_HEADING_\(suffix)"] ?? ""
            let content = fields["CONTENT_\(suffix)"] ?? fields["INCIDENT_DETAIL_\(suffix)"] ?? ""
            if !content.isEmpty {
                results.append(
                    NewsTrafficIncident(
                        id: "transport-department-\(fields["ID"] ?? UUID().uuidString)",
                        heading: heading,
                        content: content,
                        announcedAt: Self.dateFormatter.date(from: (fields["ANNOUNCEMENT_DATE"] ?? "").replacingOccurrences(of: "T", with: " "))
                    )
                )
            }
        } else if !value.isEmpty {
            fields[elementName] = value
        }
        currentText = ""
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private final class NewsTrafficParser: NSObject, XMLParserDelegate {
    private let language: TransitLanguage
    private var currentText = ""
    private var fields: [String: String] = [:]
    private var results: [NewsTrafficNotice] = []

    init(language: TransitLanguage) {
        self.language = language
    }

    func parse(_ data: Data) throws -> [NewsTrafficNotice] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return results
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        if elementName == "message" { fields = [:] }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "message" {
            let contentKey = language == .english ? "EngText" : "ChinText"
            let shortKey = language == .english ? "EngShort" : "ChinShort"
            let content = fields[contentKey] ?? fields[shortKey] ?? ""
            if !content.isEmpty {
                results.append(
                    NewsTrafficNotice(
                        id: "data-gov-hk-\(fields["msgID"] ?? UUID().uuidString)",
                        content: content,
                        announcedAt: Self.parseDate(fields["ReferenceDate"])
                    )
                )
            }
        } else if !value.isEmpty {
            fields[elementName] = value
        }
        currentText = ""
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        for (locale, format) in [
            ("zh_HK", "yyyy/M/d a hh:mm:ss"),
            ("en_US_POSIX", "yyyy/M/d hh:mm:ss a"),
            ("en_US_POSIX", "yyyy/M/d HH:mm:ss")
        ] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: locale)
            formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

extension TransitLanguage {
    fileprivate var newsLanguageCode: String {
        switch self {
        case .english: "en"
        case .traditionalChinese: "tc"
        case .simplifiedChinese: "sc"
        }
    }

    func newsText(_ english: String, _ traditional: String, _ simplified: String) -> String {
        switch self {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }
}

private struct NewsCurrentWeatherPayload: Decodable {
    let icon: [Int]
    let temperature: NewsMeasurementGroup
    let humidity: NewsMeasurementGroup
    let rainfall: NewsRainfallGroup?
    let uvindex: NewsMeasurementGroup?
}

private struct NewsForecastPayload: Decodable {
    let weatherForecast: [NewsForecastDay]
}

private struct NewsForecastDay: Decodable {
    let forecastDate: String
    let ForecastIcon: Int
    let forecastWeather: String
    let forecastMaxtemp: NewsForecastMeasurement?
    let forecastMintemp: NewsForecastMeasurement?
}

private struct NewsForecastMeasurement: Decodable {
    let value: Double?
}

private struct NewsLocalForecastPayload: Decodable {
    let forecastDesc: String
    let outlook: String
}

private struct NewsMeasurementGroup: Decodable {
    let data: [NewsMeasurement]

    var preferredValue: Double? {
        data.first(where: { $0.place == "Hong Kong Observatory" })?.value
            ?? data.first?.value
    }
}

private struct NewsMeasurement: Decodable {
    let place: String
    let value: Double
}

private struct NewsRainfallGroup: Decodable { let data: [NewsRainfallMeasurement] }
private struct NewsRainfallMeasurement: Decodable {
    let max: Double?
    let min: Double?
    var maximumValue: Double { max ?? min ?? 0 }
}
private struct NewsWarningPayload: Decodable {
    let name: String
    let actionCode: String
}
private struct NewsTipPayload: Decodable { let swt: [NewsTipRecord] }
private struct NewsTipRecord: Decodable { let desc: String }
