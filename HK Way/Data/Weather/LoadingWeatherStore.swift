import Foundation
import Observation

@MainActor
@Observable
final class LoadingWeatherStore {
    private(set) var temperature: Double?
    private(set) var humidity: Double?
    private(set) var symbol = "cloud.fill"
    private(set) var condition = "Current conditions"
    private var warningNames: [TransitLanguage: String] = [:]
    private var weatherIcon = 53

    func refresh() async {
        async let current = fetchCurrent()
        async let englishWarnings = fetchWarnings(languageCode: "en")
        async let traditionalChineseWarnings = fetchWarnings(languageCode: "tc")
        async let simplifiedChineseWarnings = fetchWarnings(languageCode: "sc")
        let (currentResult, english, traditionalChinese, simplifiedChinese) = await (
            current,
            englishWarnings,
            traditionalChineseWarnings,
            simplifiedChineseWarnings
        )
        temperature = currentResult?.temperature
        humidity = currentResult?.humidity
        symbol = currentResult?.symbol ?? symbol
        condition = currentResult?.condition ?? condition
        weatherIcon = currentResult?.icon ?? weatherIcon
        let warningKey = Set(english.keys)
            .union(traditionalChinese.keys)
            .union(simplifiedChinese.keys)
            .sorted()
            .first
        if let warningKey {
            warningNames = [
                .english: english[warningKey],
                .traditionalChinese: traditionalChinese[warningKey],
                .simplifiedChinese: simplifiedChinese[warningKey]
            ].compactMapValues { $0 }
        } else {
            warningNames = [:]
        }
    }

    func condition(for language: TransitLanguage) -> String {
        switch (weatherIcon, language) {
        case (50, .english): "Sunny"
        case (50, .traditionalChinese): "天晴"
        case (50, .simplifiedChinese): "晴朗"
        case (51, .english): "Sunny periods"
        case (51, .traditionalChinese): "短暫陽光"
        case (51, .simplifiedChinese): "短暂阳光"
        case (52, .english): "Sunny intervals"
        case (52, .traditionalChinese): "間有陽光"
        case (52, .simplifiedChinese): "间有阳光"
        case (53, .english): "Cloudy"
        case (53, .traditionalChinese): "多雲"
        case (53, .simplifiedChinese): "多云"
        case (60...65, .english): "Rain"
        case (60...65, .traditionalChinese): "有雨"
        case (60...65, .simplifiedChinese): "有雨"
        case (80...84, .english): "Windy"
        case (80...84, .traditionalChinese): "大風"
        case (80...84, .simplifiedChinese): "大风"
        case (85, .english): "Hot"
        case (85, .traditionalChinese): "炎熱"
        case (85, .simplifiedChinese): "炎热"
        case (_, .english): "Current conditions"
        case (_, .traditionalChinese): "現時天氣"
        case (_, .simplifiedChinese): "目前天氣"
        }
    }

    func warning(for language: TransitLanguage) -> String? {
        warningNames[language] ?? warningNames[.english]
    }

    var hasWeatherWarning: Bool {
        !warningNames.isEmpty
    }

    var isThunderstorm: Bool {
        weatherIcon == 64
    }

    var isRainy: Bool {
        (60...65).contains(weatherIcon)
    }

    var isWindy: Bool {
        (80...84).contains(weatherIcon)
    }

    var isHot: Bool {
        weatherIcon == 85
    }

    var isSunny: Bool {
        weatherIcon == 50
    }

    private func fetchCurrent() async -> Current? {
        guard let url = URL(string: "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=rhrread&lang=en"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(CurrentPayload.self, from: data),
              let value = payload.temperature.data.first(where: { $0.place == "Hong Kong Observatory" })?.value ?? payload.temperature.data.first?.value,
              let icon = payload.icon.first else { return nil }
        let humidity = payload.humidity.data.first(where: { $0.place == "Hong Kong Observatory" })?.value ?? payload.humidity.data.first?.value
        return Current(
            temperature: value,
            humidity: humidity,
            symbol: Self.symbol(for: icon),
            condition: Self.condition(for: icon),
            icon: icon
        )
    }

    private func fetchWarnings(languageCode: String) async -> [String: String] {
        guard let url = URL(string: "https://data.weather.gov.hk/weatherAPI/opendata/weather.php?dataType=warnsum&lang=\(languageCode)"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let warnings = try? JSONDecoder().decode([String: WarningPayload].self, from: data) else { return [:] }
        return warnings.mapValues(\.name)
    }

    private static func symbol(for icon: Int) -> String {
        switch icon {
        case 50...52, 70, 75, 76: "sun.max.fill"
        case 60...63, 65: "cloud.rain.fill"
        case 64: "cloud.bolt.rain.fill"
        case 80...84: "wind"
        default: "cloud.fill"
        }
    }

    private static func condition(for icon: Int) -> String {
        switch icon {
        case 50: "Sunny"
        case 51...52: "Sunny intervals"
        case 53: "Cloudy"
        case 60...65: "Rain"
        case 80...84: "Windy"
        case 85: "Hot"
        default: "Current conditions"
        }
    }
}

private struct Current { let temperature: Double; let humidity: Double?; let symbol: String; let condition: String; let icon: Int }
private struct CurrentPayload: Decodable { let icon: [Int]; let temperature: MeasurementGroup; let humidity: MeasurementGroup }
private struct MeasurementGroup: Decodable { let data: [Measurement] }
private struct Measurement: Decodable { let place: String; let value: Double }
private struct WarningPayload: Decodable { let name: String }
