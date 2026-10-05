import SwiftUI

@main
struct HKWayWatchApp: App {
    @State private var journeyStore = WatchJourneyStore()

    var body: some Scene {
        WindowGroup {
            WatchJourneyListView()
                .environment(journeyStore)
                .task {
                    WatchNotificationManager.shared.configure()
                    journeyStore.activate()
                }
        }
    }
}
