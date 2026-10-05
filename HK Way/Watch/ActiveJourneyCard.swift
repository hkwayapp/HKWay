import SwiftUI

struct ActiveJourneyCard: View {
    @Environment(\.transitLanguage) private var language
    private var manager: JourneyAlertManager { .shared }

    var body: some View {
        if manager.isTracking, let snapshot = manager.activeSnapshot {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("Active Journey", "進行中的行程", "进行中的行程"))
                            .font(.headline)
                        Text("\(localized("Route", "路線", "路线")) \(snapshot.routeNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(localized("End", "結束", "结束"), role: .destructive) {
                        manager.stop()
                        WatchSyncManager.shared.stopJourney()
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Label(
                        manager.destinationName(for: language) ?? "",
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.subheadline.weight(.semibold))

                    Spacer()

                    if let remaining = manager.remainingStops {
                        Text(remainingText(remaining))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if manager.isOutsideRoute {
                    Label(
                        localized(
                            "Away from this route · alerts paused",
                            "已離開此路線 · 落車提示已暫停",
                            "已离开此路线 · 下车提醒已暂停"
                        ),
                        systemImage: "location.slash.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                }

                Text(localized(
                    "Alert set for one stop before your destination.",
                    "已設定於目的地前一站通知你。",
                    "已设置于目的地前一站通知你。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func remainingText(_ count: Int) -> String {
        switch language {
        case .english: "\(count) stop\(count == 1 ? "" : "s") remaining"
        case .traditionalChinese: "尚餘 \(count) 站"
        case .simplifiedChinese: "还剩 \(count) 站"
        }
    }

    private func localized(
        _ english: String,
        _ traditional: String,
        _ simplified: String
    ) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }
}
