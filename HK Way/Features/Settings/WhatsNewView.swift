import SwiftUI

struct WhatsNewView: View {
    static let appleTVAnnouncementStorageKey = "whatsNew.appleTVComingSoon.v1"

    @Environment(\.transitLanguage) private var environmentLanguage

    private let selectedLanguage: TransitLanguage?

    let onDismiss: () -> Void

    init(
        language: TransitLanguage? = nil,
        onDismiss: @escaping () -> Void
    ) {
        selectedLanguage = language
        self.onDismiss = onDismiss
    }

    private var language: TransitLanguage {
        selectedLanguage ?? environmentLanguage
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CustomAppBackgroundView()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "appletv.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(title)
                            .font(.largeTitle.bold())

                        Text(appleTVTitle)
                            .font(.title2.bold())

                        Text(message)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    Spacer()

                    Button(action: onDismiss) {
                        Text(doneTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
            }
        }
    }

    private var title: String {
        localized("What's New", "最新功能", "最新功能")
    }

    private var appleTVTitle: String {
        localized("HK Way for Apple TV", "Apple TV 版「喂!香港」", "Apple TV 版“喂!香港”")
    }

    private var message: String {
        localized(
            "The Apple TV app is coming soon, bringing bus arrivals, weather and traffic news to the big screen.",
            "Apple TV 版即將推出，讓你在大螢幕上查看巴士到站時間、天氣及交通消息。",
            "Apple TV 版即将推出，让你在大屏幕上查看巴士到站时间、天气及交通消息。"
        )
    }

    private var doneTitle: String {
        localized("Got it", "知道了", "知道了")
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

#Preview {
    WhatsNewView {}
}
