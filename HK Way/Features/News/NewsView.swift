import SwiftUI

struct NewsView: View {
    enum Content: Hashable {
        case all
        case weather
        case traffic
    }

    private enum TrafficFeed: Hashable {
        case standard
        case special
    }

    @Environment(\.transitLanguage) private var language
    @State private var store = NewsStore()
    @State private var trafficFeed: TrafficFeed = .standard
    let content: Content

    init(content: Content = .all) {
        self.content = content
    }

    var body: some View {
        NavigationStack {
            List {
                if content != .traffic {
                    weatherSection
                }
                if content != .weather {
                    trafficSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(navigationTitle)
            .refreshable { await store.refresh(language: language) }
            .task(id: language.rawValue) { await store.refresh(language: language) }
            .overlay {
                if store.isLoading && store.weather == nil && store.trafficNotices.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private var navigationTitle: String {
        switch content {
        case .all:
            language.newsText("News", "最新消息", "最新消息")
        case .weather:
            language.newsText("Weather Report", "天氣報告", "天气报告")
        case .traffic:
            language.newsText("Traffic News", "交通消息", "交通消息")
        }
    }

    private var weatherSection: some View {
        Group {
            currentWeatherSection
            weatherForecastSection
            weatherUpdatesSection
        }
    }

    private var currentWeatherSection: some View {
        Section {
            if let weather = store.weather {
                HStack(spacing: 16) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(weather.condition(language: language))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(weatherDetails(weather))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } else if store.hasWeatherError {
                statusRow(
                    icon: "exclamationmark.triangle",
                    text: language.newsText(
                        "Weather information is temporarily unavailable.",
                        "天氣資訊暫時未能提供。",
                        "天气信息暂时无法提供。"
                    )
                )
            }

            ForEach(store.weatherAlerts) { alert in
                Label {
                    Text(alert.name).foregroundStyle(.primary)
                } icon: {
                    Image(systemName: alert.symbolName).foregroundStyle(.orange)
                }
            }
        } header: {
            Label(
                language.newsText("Weather", "天氣", "天气"),
                systemImage: "cloud.sun.fill"
            )
        }
    }

    
    
    @ViewBuilder
    private var weatherForecastSection: some View {
        if !store.dailyForecasts.isEmpty {
            Section {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(store.dailyForecasts) { forecast in
                            VStack(spacing: 8) {
                                Text(forecast.date, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Image(systemName: forecast.symbolName)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                    .frame(height: 25)
                                Text(temperatureRange(forecast))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                Text(forecast.summary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(width: 96, height: 130)
                            .padding(10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            } header: {
                Label(
                    language.newsText("7-Day Outlook", "九天天氣預報", "九天天气预报"),
                    systemImage: "calendar"
                )
            }
        }
    }

    
    
    @ViewBuilder
    private var weatherUpdatesSection: some View {
        if !store.forecastUpdates.isEmpty || !store.weatherTips.isEmpty {
            Section {
                ForEach(store.forecastUpdates) { update in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(update.title).font(.headline)
                        Text(update.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 3)
                }

                ForEach(store.weatherTips) { tip in
                    Label {
                        Text(tip.detail).foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "info.circle.fill").foregroundStyle(.tint)
                    }
                }
            } header: {
                Label(
                    language.newsText("Weather Updates", "天氣消息", "天气消息"),
                    systemImage: "newspaper.fill"
                )
            }
        }
    }

    private var trafficSection: some View {
        Group {
            Picker("Traffic feed", selection: $trafficFeed) {
                Text(language.newsText("Traffic News", "交通消息", "交通消息")).tag(TrafficFeed.standard)
                Text(language.newsText("Special Traffic", "特別交通", "特别交通")).tag(TrafficFeed.special)
            }
            .pickerStyle(.segmented)

            if trafficFeed == .standard {
                standardTrafficSection
            } else {
                specialTrafficSection
            }
        }
    }


    @ViewBuilder
    private var standardTrafficSection: some View {
        if store.trafficIncidents.isEmpty {
            Section {
                statusRow(
                    icon: store.hasTrafficIncidentError ? "exclamationmark.triangle" : "checkmark.circle",
                    text: store.hasTrafficIncidentError
                        ? language.newsText("Traffic information is temporarily unavailable.", "交通資訊暫時未能提供。", "交通信息暂时无法提供。")
                        : language.newsText("No current traffic incidents.", "現時沒有交通事故消息。", "目前没有交通事故消息。")
                )
            } header: {
                Label(language.newsText("Traffic News", "交通消息", "交通消息"), systemImage: "car.fill")
            }
        } else {
            ForEach(Array(store.trafficIncidents.enumerated()), id: \.element.id) { index, incident in
                Section {
                    trafficIncidentRow(incident)
                } header: {
                    if index == 0 {
                        Label(language.newsText("Traffic News", "交通消息", "交通消息") + " (\(store.trafficIncidents.count))", systemImage: "car.fill")
                    }
                }
            }
        }
    }


    @ViewBuilder
    private var specialTrafficSection: some View {
        if store.trafficNotices.isEmpty {
            Section {
                statusRow(
                    icon: store.hasTrafficError ? "exclamationmark.triangle" : "checkmark.circle",
                    text: store.hasTrafficError
                        ? language.newsText("Special traffic information is temporarily unavailable.", "特別交通消息暫時未能提供。", "特别交通消息暂时无法提供。")
                        : language.newsText("No special traffic news at present.", "現時沒有特別交通消息。", "目前没有特别交通消息。")
                )
            } header: {
                trafficSectionHeader
            }
        } else {
            ForEach(Array(store.trafficNotices.enumerated()), id: \.element.id) { index, notice in
                Section {
                    trafficNoticeRow(notice)
                } header: {
                    if index == 0 { trafficSectionHeader }
                }
            }
        }
    }

    private var trafficSectionHeader: some View {
        Label(
            language.newsText("Special Traffic News", "特別交通消息", "特别交通消息")
                + " (\(store.trafficNotices.count))",
            systemImage: "car.fill"
        )
    }

    private func trafficIncidentRow(_ incident: NewsTrafficIncident) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if !incident.heading.isEmpty {
                Text(incident.heading)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            Text(incident.content)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let announcedAt = incident.announcedAt {
                Text(announcedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func trafficNoticeRow(_ notice: NewsTrafficNotice) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(notice.content)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let announcedAt = notice.announcedAt {
                Text(announcedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func weatherDetails(_ weather: NewsWeatherSnapshot) -> String {
        var values: [String] = []
        if let temperature = weather.temperature {
            values.append("\(Int(temperature.rounded()))°C")
        }
        if let humidity = weather.humidity {
            values.append(
                language.newsText("Humidity", "濕度", "湿度")
                    + " \(Int(humidity.rounded()))%"
            )
        }
        if let rainfall = weather.rainfall {
            values.append(
                language.newsText("Rainfall", "雨量", "雨量")
                    + " \(rainfall.formatted(.number.precision(.fractionLength(0...1)))) mm"
            )
        }
        if let uvIndex = weather.ultravioletIndex {
            values.append("UV \(uvIndex.formatted(.number.precision(.fractionLength(0...1))))")
        }
        return values.joined(separator: " · ")
    }

    private func temperatureRange(_ forecast: NewsDailyForecast) -> String {
        switch (forecast.minimumTemperature, forecast.maximumTemperature) {
        case let (minimum?, maximum?):
            return "\(Int(minimum.rounded()))–\(Int(maximum.rounded()))°"
        case let (minimum?, nil):
            return "\(Int(minimum.rounded()))°"
        case let (nil, maximum?):
            return "\(Int(maximum.rounded()))°"
        case (nil, nil):
            return "—"
        }
    }

    private func statusRow(icon: String, text: String) -> some View {
        Label {
            Text(text).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary)
        }
    }
}
