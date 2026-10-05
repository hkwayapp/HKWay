import ActivityKit
import SwiftUI
import WidgetKit

nonisolated struct StopAlertAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var status: String
        var detail: String
        var nextStop: String
        var remainingStops: Int
        var totalStops: Int
    }

    var routeNumber: String
    var targetStop: String
}

struct StopAlertLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StopAlertAttributes.self) { context in
            let completedStops = max(context.state.totalStops - context.state.remainingStops, 0)
            let progress = Double(completedStops) / Double(max(context.state.totalStops, 1))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    Text(context.state.status)
                        .font(.headline.bold())
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(context.attributes.routeNumber)
                        .font(.title2.bold().monospacedDigit())
                }

                HStack(spacing: 8) {
                    Image(systemName: "bus.fill")
                        .foregroundStyle(.tint)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.22))
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    Image(systemName: context.state.nextStop.isEmpty ? "flag.checkered" : "mappin.circle.fill")
                        .foregroundStyle(.tint)
                }

                if !context.state.nextStop.isEmpty {
                    Label(context.state.nextStop, systemImage: "arrow.right.circle.fill")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                }

                HStack {
                    Text(context.state.detail)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(context.state.remainingStops)/\(context.state.totalStops)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .activityBackgroundTint(Color.black.opacity(0.84))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.routeNumber)
                        .font(.title.bold().monospacedDigit())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(context.state.status)
                            .font(.caption.bold())
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                        Text("\(context.state.remainingStops)/\(context.state.totalStops)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 10)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let completedStops = max(context.state.totalStops - context.state.remainingStops, 0)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "bus.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.tint)
                            ProgressView(
                                value: Double(completedStops),
                                total: Double(max(context.state.totalStops, 1))
                            )
                            .tint(Color.accentColor)
                            .frame(height: 5)
                        }

                        HStack(alignment: .top, spacing: 16) {
                            if !context.state.nextStop.isEmpty {
                                Text(context.state.nextStop)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Text(context.state.detail)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Text(context.attributes.routeNumber)
                    .font(.caption.bold().monospacedDigit())
            } compactTrailing: {
                Image(systemName: "bus.fill")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            } minimal: {
                Text(context.attributes.routeNumber)
                    .font(.caption2.bold().monospacedDigit())
            }
            .widgetURL(URL(string: "hkway://stop-alert"))
            .keylineTint(.accentColor)
        }
    }
}
