import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

private enum AdMobConfiguration {
    static let sidebarBannerUnitID: String = {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        return "ca-app-pub-7998867923191797/3615668104"
        #endif
    }()
}

/// The app's only advertising placement. It is deliberately scoped to the
/// bottom of the sidebar and collapses completely when no ad is available.
struct SidebarAdvertisementView: View {
    @State private var canRequestAds = false
    @State private var adLoadSucceeded: Bool?

    var body: some View {
        Group {
            if canRequestAds {
                SidebarBannerContainer(adLoadSucceeded: $adLoadSucceeded)
                    .frame(
                        width: 320,
                        height: adLoadSucceeded == false ? 0 : 50
                    )
                    .clipped()
                    .accessibilityLabel("Advertisement")
                    .padding(.vertical, adLoadSucceeded == true ? 6 : 0)
                    .frame(maxWidth: .infinity)
                    .background(adLoadSucceeded == true ? Color(uiColor: .systemBackground) : .clear)
            }
        }
        .frame(maxWidth: .infinity)
        .task {
            await prepareAdvertisingIfNeeded()
        }
    }

    @MainActor
    private var activeViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    private func prepareAdvertisingIfNeeded() async {
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(
                with: RequestParameters()
            ) { _ in
                continuation.resume()
            }
        }

        try? await ConsentForm.loadAndPresentIfRequired(from: activeViewController)

        guard ConsentInformation.shared.canRequestAds else { return }
        await MobileAds.shared.start()
        canRequestAds = true
    }
}

private struct SidebarBannerContainer: UIViewRepresentable {
    @Binding var adLoadSucceeded: Bool?

    func makeCoordinator() -> Coordinator {
        Coordinator(adLoadSucceeded: $adLoadSucceeded)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdMobConfiguration.sidebarBannerUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        private let adLoadSucceeded: Binding<Bool?>

        init(adLoadSucceeded: Binding<Bool?>) {
            self.adLoadSucceeded = adLoadSucceeded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            adLoadSucceeded.wrappedValue = true
        }

        func bannerView(
            _ bannerView: BannerView,
            didFailToReceiveAdWithError error: Error
        ) {
            adLoadSucceeded.wrappedValue = false
            print("Sidebar banner failed to load:", error.localizedDescription)
        }
    }
}
