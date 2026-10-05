import Foundation
import Observation

enum TVBackgroundPreview: String, CaseIterable, Identifiable {
    case automatic
    case sunny01
    case sunny03
    case sunny04
    case sunny05
    case sunny06
    case sunny07
    case sunny11
    case sunny13
    case cloudy01
    case cloudy02
    case cloudy03
    case rainy01
    case rainy02
    case sunset01
    case sunset02
    case sunset03
    case night01

    var id: String { rawValue }

    var imageName: String? {
        switch self {
        case .automatic: nil
        case .sunny01: "HKPersonalSunny01"
        case .sunny03: "HKPersonalSunny03"
        case .sunny04: "HKPersonalSunny04"
        case .sunny05: "HKPersonalSunny05"
        case .sunny06: "HKPersonalSunny06"
        case .sunny07: "HKPersonalSunny07"
        case .sunny11: "HKPersonalSunny11"
        case .sunny13: "HKPersonalSunny13"
        case .cloudy01: "HKPersonalCloudy01"
        case .cloudy02: "HKPersonalCloudy02"
        case .cloudy03: "HKPersonalCloudy03"
        case .rainy01: "HKPersonalRainy01"
        case .rainy02: "HKPersonalRainy02"
        case .sunset01: "HKPersonalSunset01"
        case .sunset02: "HKPersonalSunset02"
        case .sunset03: "HKPersonalSunset03"
        case .night01: "HKPersonalNight01"
        }
    }

    func name(_ language: TVLanguage) -> String {
        switch (self, language) {
        case (.automatic, .english): "Automatic"
        case (.automatic, .traditionalChinese): "自動"
        case (.automatic, .simplifiedChinese): "自动"
        case (.sunny01, .english): "Sunny 1"
        case (.sunny01, .traditionalChinese), (.sunny01, .simplifiedChinese): "晴天 1"
        case (.sunny03, .english): "Sunny 3"
        case (.sunny03, .traditionalChinese), (.sunny03, .simplifiedChinese): "晴天 3"
        case (.sunny04, .english): "Sunny 4"
        case (.sunny04, .traditionalChinese), (.sunny04, .simplifiedChinese): "晴天 4"
        case (.sunny05, .english): "Sunny 5"
        case (.sunny05, .traditionalChinese), (.sunny05, .simplifiedChinese): "晴天 5"
        case (.sunny06, .english): "Sunny 6"
        case (.sunny06, .traditionalChinese), (.sunny06, .simplifiedChinese): "晴天 6"
        case (.sunny07, .english): "Sunny 7"
        case (.sunny07, .traditionalChinese), (.sunny07, .simplifiedChinese): "晴天 7"
        case (.sunny11, .english): "Sunny 11"
        case (.sunny11, .traditionalChinese), (.sunny11, .simplifiedChinese): "晴天 11"
        case (.sunny13, .english): "Sunny 13"
        case (.sunny13, .traditionalChinese), (.sunny13, .simplifiedChinese): "晴天 13"
        case (.cloudy01, .english): "Cloudy 1"
        case (.cloudy01, .traditionalChinese): "多雲 1"
        case (.cloudy01, .simplifiedChinese): "多云 1"
        case (.cloudy02, .english): "Cloudy 2"
        case (.cloudy02, .traditionalChinese): "多雲 2"
        case (.cloudy02, .simplifiedChinese): "多云 2"
        case (.cloudy03, .english): "Cloudy 3"
        case (.cloudy03, .traditionalChinese): "多雲 3"
        case (.cloudy03, .simplifiedChinese): "多云 3"
        case (.rainy01, .english): "Rainy 1"
        case (.rainy01, .traditionalChinese), (.rainy01, .simplifiedChinese): "雨天 1"
        case (.rainy02, .english): "Rainy 2"
        case (.rainy02, .traditionalChinese), (.rainy02, .simplifiedChinese): "雨天 2"
        case (.sunset01, .english): "Sunset 1"
        case (.sunset01, .traditionalChinese), (.sunset01, .simplifiedChinese): "日落 1"
        case (.sunset02, .english): "Sunset 2"
        case (.sunset02, .traditionalChinese), (.sunset02, .simplifiedChinese): "日落 2"
        case (.sunset03, .english): "Sunset 3"
        case (.sunset03, .traditionalChinese), (.sunset03, .simplifiedChinese): "日落 3"
        case (.night01, .english): "Night 1"
        case (.night01, .traditionalChinese): "晚上 1"
        case (.night01, .simplifiedChinese): "夜间 1"
        }
    }
}

enum TVBackgroundCategory: String, CaseIterable, Identifiable {
    case sunny
    case cloudy
    case rainy
    case sunset
    case night

    var id: String { rawValue }

    var options: [TVBackgroundPreview] {
        switch self {
        case .sunny: [
            .sunny01, .sunny03, .sunny04, .sunny05,
            .sunny06, .sunny07,
            .sunny11, .sunny13
        ]
        case .cloudy: [.cloudy01, .cloudy02, .cloudy03]
        case .rainy: [.rainy01, .rainy02]
        case .sunset: [.sunset01, .sunset02, .sunset03]
        case .night: [.night01]
        }
    }

    func name(_ language: TVLanguage) -> String {
        switch (self, language) {
        case (.sunny, .english): "Sunny"
        case (.sunny, .traditionalChinese), (.sunny, .simplifiedChinese): "晴天"
        case (.cloudy, .english): "Cloudy"
        case (.cloudy, .traditionalChinese): "多雲"
        case (.cloudy, .simplifiedChinese): "多云"
        case (.rainy, .english): "Rainy"
        case (.rainy, .traditionalChinese), (.rainy, .simplifiedChinese): "雨天"
        case (.sunset, .english): "Sunset"
        case (.sunset, .traditionalChinese), (.sunset, .simplifiedChinese): "日落"
        case (.night, .english): "Night"
        case (.night, .traditionalChinese): "晚上"
        case (.night, .simplifiedChinese): "夜间"
        }
    }
}

enum TVWeatherScene {
    case sunny
    case cloudy
    case rainy
    case sunset
    case night

    var imageNames: [String] {
        switch self {
        case .sunny: [
            "HKPersonalSunny01", "HKPersonalSunny03",
            "HKPersonalSunny04", "HKPersonalSunny05", "HKPersonalSunny06",
            "HKPersonalSunny07", "HKPersonalSunny11", "HKPersonalSunny13"
        ]
        case .cloudy: ["HKPersonalCloudy01", "HKPersonalCloudy02", "HKPersonalCloudy03"]
        case .rainy: ["HKPersonalRainy01", "HKPersonalRainy02"]
        case .sunset: ["HKPersonalSunset01", "HKPersonalSunset02", "HKPersonalSunset03"]
        case .night: ["HKPersonalNight01"]
        }
    }
}

struct TVCurrentWeather: Sendable, Equatable {
    let temperature: Double?
    let humidity: Double?
    let rainfall: Double?
    let uvIndex: Double?
    let icon: Int
    let updatedAt: Date

    func condition(_ language: TVLanguage) -> String {
        switch icon {
        case 50: language.text("Sunny", "天晴", "晴朗")
        case 51: language.text("Sunny periods", "短暫陽光", "短暂阳光")
        case 52: language.text("Sunny intervals", "間有陽光", "间有阳光")
        case 53: language.text("Cloudy", "多雲", "多云")
        case 54: language.text("Overcast", "密雲", "阴天")
        case 60: language.text("Cloudy with rain", "多雲有雨", "多云有雨")
        case 61: language.text("Light rain", "微雨", "小雨")
        case 62: language.text("Rain", "有雨", "有雨")
        case 63: language.text("Heavy rain", "大雨", "大雨")
        case 64: language.text("Thunderstorms", "雷暴", "雷暴")
        case 65: language.text("Showers", "驟雨", "阵雨")
        case 70: language.text("Fine", "天色良好", "天气良好")
        case 71...77: language.text("Dry", "乾燥", "干燥")
        case 80...84: language.text("Windy", "大風", "大风")
        case 85: language.text("Hot", "炎熱", "炎热")
        case 90...93: language.text("Cool", "清涼", "清凉")
        default: language.text("Current conditions", "現時天氣", "当前天气")
        }
    }

    var symbolName: String {
        switch icon {
        case 50...52, 70, 75, 76: "sun.max.fill"
        case 60...63, 65: "cloud.rain.fill"
        case 64: "cloud.bolt.rain.fill"
        case 80...84: "wind"
        case 85: "thermometer.sun.fill"
        default: "cloud.fill"
        }
    }

}

struct TVWeatherWarning: Identifiable, Sendable, Equatable {
    let name: String
    let kind: String
    let code: String
    let issuedAt: Date?
    let updatedAt: Date?

    var id: String { kind }

    var symbolName: String {
        switch kind {
        case "WMSGNL": "wind"
        case "WRAIN": "cloud.heavyrain.fill"
        case "WTCSGNL": "hurricane"
        case "WTCPRE8": "bell.and.waves.left.and.right.fill"
        case "WTS": "cloud.bolt.rain.fill"
        case "WHOT": "thermometer.sun.fill"
        case "WCOLD", "WFROST": "thermometer.snowflake"
        case "WL": "mountain.2.fill"
        case "WFNTSA", "WTMW": "water.waves"
        case "WFIRE": "flame.fill"
        default: "exclamationmark.triangle.fill"
        }
    }

    var typhoonArtworkName: String? {
        guard kind == "WTCSGNL" else { return nil }
        return switch code.uppercased() {
        case "TC1": "TyphoonSignalT1"
        case "TC3": "TyphoonSignalT3"
        case "TC8NE": "TyphoonSignalT8NE"
        case "TC8SE": "TyphoonSignalT8SE"
        case "TC8SW": "TyphoonSignalT8SW"
        case "TC8NW": "TyphoonSignalT8NW"
        case "TC9": "TyphoonSignalT9"
        case "TC10": "TyphoonSignalT10"
        default: nil
        }
    }

    var rainfallSignalLevel: TVRainfallSignalLevel? {
        guard kind == "WRAIN" else { return nil }
        let normalizedCode = code.uppercased()
        if normalizedCode.contains("WRAINB") || normalizedCode.contains("BLACK") {
            return .black
        }
        if normalizedCode.contains("WRAINR") || normalizedCode.contains("RED") {
            return .red
        }
        if normalizedCode.contains("WRAINA") || normalizedCode.contains("AMBER") {
            return .amber
        }
        return nil
    }

    var priority: Int {
        switch kind {
        case "WTCSGNL": 0
        case "WRAIN": 1
        case "WMSGNL": 2
        default: 3
        }
    }
}

enum TVRainfallSignalLevel: Sendable {
    case amber
    case red
    case black
}

struct TVSpecialWeatherTip: Sendable, Equatable {
    let detail: String
    let updatedAt: Date?
}

@MainActor
@Observable
final class TVWeatherBackgroundStore {
    private(set) var daytimeScene: TVWeatherScene = .sunny
    private(set) var imageName: String
    private(set) var currentWeather: TVCurrentWeather?
    private(set) var activeWarnings: [TVWeatherWarning] = []
    private(set) var specialWeatherTips: [TVSpecialWeatherTip] = []
    private(set) var hasWeatherError = false
    private var selectedScene: TVWeatherScene?

    init() {
        let scene = Self.timeScene(daytime: .sunny)
        imageName = scene.imageNames.randomElement() ?? "HKPersonalSunny01"
        selectedScene = scene
    }

    private var currentScene: TVWeatherScene {
        Self.timeScene(daytime: daytimeScene)
    }

    private static func timeScene(daytime: TVWeatherScene) -> TVWeatherScene {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: .now)
        return switch hour {
        case 6..<17: daytime
        case 17..<19: .sunset
        default: .night
        }
    }

    func refresh(language: TVLanguage) async {
        guard let url = URL(string: "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=rhrread&lang=en") else { return }
        defer { selectImageIfNeeded() }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                hasWeatherError = true
                return
            }
            let report = try JSONDecoder().decode(CurrentWeatherReport.self, from: data)
            guard let icon = report.icon.first else { return }
            daytimeScene = Self.scene(for: icon)
            currentWeather = TVCurrentWeather(
                temperature: report.temperature.preferredValue(place: "Hong Kong Observatory"),
                humidity: report.humidity.preferredValue(place: "Hong Kong Observatory"),
                rainfall: report.rainfall?.data.map(\.maxValue).max(),
                uvIndex: report.uvindex?.data.first?.value,
                icon: icon,
                updatedAt: Self.parseDate(report.updateTime) ?? .now
            )
            hasWeatherError = false
        } catch {
            hasWeatherError = true
        }

        await refreshAlerts(language: language)
    }

    private func refreshAlerts(language: TVLanguage) async {
        let languageCode = switch language {
        case .english: "en"
        case .traditionalChinese: "tc"
        case .simplifiedChinese: "sc"
        }

        if let warningURL = URL(string: "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=warnsum&lang=\(languageCode)") {
            do {
                let (data, response) = try await URLSession.shared.data(from: warningURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let records = try JSONDecoder().decode([String: WeatherWarningRecord].self, from: data)
                activeWarnings = records
                    .filter { $0.value.actionCode != "CANCEL" }
                    .map { kind, record in
                        TVWeatherWarning(
                            name: record.name,
                            kind: kind,
                            code: record.code,
                            issuedAt: Self.parseDate(record.issueTime),
                            updatedAt: Self.parseDate(record.updateTime)
                        )
                    }
                    .sorted { ($0.priority, $0.name) < ($1.priority, $1.name) }
            } catch {
                // Retain the last successful warning state during a temporary network failure.
            }
        }

        if let tipURL = URL(string: "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=swt&lang=\(languageCode)") {
            do {
                let (data, response) = try await URLSession.shared.data(from: tipURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let report = try JSONDecoder().decode(SpecialWeatherTipReport.self, from: data)
                specialWeatherTips = report.swt.map {
                    TVSpecialWeatherTip(
                        detail: $0.desc,
                        updatedAt: Self.parseDate($0.updateTime)
                    )
                }
            } catch {
                // Retain the last successful special-weather tip during a temporary network failure.
            }
        }
    }

    private func selectImageIfNeeded() {
        let scene = currentScene
        guard scene != selectedScene else { return }
        imageName = scene.imageNames.randomElement() ?? "HKPersonalSunny01"
        selectedScene = scene
    }

    private static func scene(for icon: Int) -> TVWeatherScene {
        switch icon {
        case 50...53, 70, 75, 76:
            .sunny
        case 62...65:
            .rainy
        default:
            .cloudy
        }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}

private struct CurrentWeatherReport: Decodable {
    let icon: [Int]
    let temperature: WeatherMeasurementGroup
    let humidity: WeatherMeasurementGroup
    let rainfall: RainfallGroup?
    let uvindex: WeatherMeasurementGroup?
    let updateTime: String?
}

private struct WeatherWarningRecord: Decodable {
    let name: String
    let code: String
    let actionCode: String
    let issueTime: String?
    let updateTime: String?
}

private struct SpecialWeatherTipReport: Decodable {
    let swt: [SpecialWeatherTipRecord]
}

private struct SpecialWeatherTipRecord: Decodable {
    let desc: String
    let updateTime: String?
}

private struct WeatherMeasurementGroup: Decodable {
    let data: [WeatherMeasurement]

    func preferredValue(place: String) -> Double? {
        data.first(where: { $0.place == place })?.value ?? data.first?.value
    }
}

private struct WeatherMeasurement: Decodable {
    let place: String
    let value: Double
}

private struct RainfallGroup: Decodable {
    let data: [RainfallMeasurement]
}

private struct RainfallMeasurement: Decodable {
    let max: Double?
    let min: Double?

    var maxValue: Double { max ?? min ?? 0 }
}
