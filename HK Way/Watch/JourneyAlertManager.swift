import CoreLocation
import Foundation
import Observation
import UserNotifications
import ActivityKit

@MainActor
@Observable
final class JourneyAlertManager: NSObject,
                                 CLLocationManagerDelegate,
                                 UNUserNotificationCenterDelegate {
    static let shared = JourneyAlertManager()

    private let locationManager = CLLocationManager()
    private var stops: [TransitWatchStop] = []
    private var destination: TransitWatchStop?
    private var language = TransitLanguage.english
    private var liveActivity: Activity<StopAlertAttributes>?
    private(set) var liveActivityStatusMessage: String?
    private(set) var didWarn = false
    private(set) var didSendFinalWarning = false
    private(set) var isTracking = false
    private(set) var activeSnapshot: TransitWidgetSnapshot?
    private(set) var originSequence: Int?
    private(set) var destinationSequence: Int?
    private(set) var remainingStops: Int?
    private(set) var isOutsideRoute = false

    private let activeJourneyKey = "activeJourneyAlert.v1"

    private struct StoredJourney: Codable {
        let snapshot: TransitWidgetSnapshot
        let originSequence: Int
        let destinationSequence: Int
        let languageRawValue: String
        let didWarn: Bool
        let didSendFinalWarning: Bool?
        let remainingStops: Int?
    }

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 20
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        restoreJourney()
    }

    func start(
        snapshot: TransitWidgetSnapshot,
        originSequence: Int,
        destinationSequence: Int,
        language: TransitLanguage
    ) {
        guard let allStops = snapshot.upcomingStops,
              let destination = allStops.first(where: {
                  $0.sequence == destinationSequence
              }) else { return }

        stops = allStops.filter {
            $0.sequence >= originSequence && $0.sequence <= destinationSequence
        }.sorted { $0.sequence < $1.sequence }
        self.destination = destination
        self.language = language
        didWarn = false
        didSendFinalWarning = false
        isOutsideRoute = false
        isTracking = true
        activeSnapshot = snapshot
        self.originSequence = originSequence
        self.destinationSequence = destinationSequence
        remainingStops = max(
            stops.firstIndex(where: { $0.sequence == destinationSequence }) ?? 0,
            0
        )
        saveJourney()
        startLiveActivity(snapshot: snapshot, destination: destination)

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                self.sendJourneyStartedNotification(destination: destination)
            }
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        isTracking = false
        activeSnapshot = nil
        originSequence = nil
        destinationSequence = nil
        remainingStops = nil
        didWarn = false
        didSendFinalWarning = false
        isOutsideRoute = false
        UserDefaults.standard.removeObject(forKey: activeJourneyKey)
        endLiveActivity()
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            if self.isTracking,
               manager.authorizationStatus == .authorizedAlways
                || manager.authorizationStatus == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.update(using: location) }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {}

    private func update(using location: CLLocation) {
        let candidates = stops.compactMap {
            stop -> (stop: TransitWatchStop, distance: CLLocationDistance)? in
            guard let latitude = stop.latitude,
                  let longitude = stop.longitude,
                  latitude != 0 || longitude != 0 else { return nil }
            let stopLocation = CLLocation(latitude: latitude, longitude: longitude)
            return (stop, location.distance(from: stopLocation))
        }
        guard let nearest = candidates.min(by: { $0.distance < $1.distance }) else {
            return
        }

        guard nearest.distance <= 1_000 else {
            if !isOutsideRoute {
                isOutsideRoute = true
                updateLiveActivityForOutsideRoute()
            }
            return
        }

        isOutsideRoute = false
        guard nearest.distance <= 400,
              let destination,
              let destinationIndex = stops.firstIndex(where: {
                  $0.sequence == destination.sequence
              }),
              let currentIndex = stops.firstIndex(where: {
                  $0.sequence == nearest.stop.sequence
              }) else { return }

        let remaining = max(destinationIndex - currentIndex, 0)
        remainingStops = remaining
        saveJourney()
        let nextStop = currentIndex + 1 < stops.count
            ? destinationName(stops[currentIndex + 1])
            : destinationName(destination)
        updateLiveActivity(
            remainingStops: remaining,
            destination: destination,
            nextStop: nextStop
        )
        if remaining == 1, !didWarn {
            didWarn = true
            sendApproachingNotification(destination: destination)
            saveJourney()
        }

        if let destinationCandidate = candidates.first(where: {
            $0.stop.sequence == destination.sequence
        }) {
            if remaining == 0,
               destinationCandidate.distance <= 300,
               !didSendFinalWarning {
                didSendFinalWarning = true
                sendFinalApproachNotification(destination: destination)
                saveJourney()
            }

            if destinationCandidate.distance <= 40 {
                stop()
            }
        } else if remaining == 0 {
            stop()
        }
    }

    func destinationName(for language: TransitLanguage) -> String? {
        guard let destination else { return nil }
        switch language {
        case .english: return destination.english
        case .traditionalChinese: return destination.traditional
        case .simplifiedChinese: return destination.simplified
        }
    }

    private func saveJourney() {
        guard isTracking,
              let snapshot = activeSnapshot,
              let originSequence,
              let destinationSequence,
              let data = try? JSONEncoder().encode(
                  StoredJourney(
                      snapshot: snapshot,
                      originSequence: originSequence,
                      destinationSequence: destinationSequence,
                      languageRawValue: language.rawValue,
                      didWarn: didWarn,
                      didSendFinalWarning: didSendFinalWarning,
                      remainingStops: remainingStops
                  )
              ) else { return }
        UserDefaults.standard.set(data, forKey: activeJourneyKey)
    }

    private func restoreJourney() {
        guard let data = UserDefaults.standard.data(forKey: activeJourneyKey),
              let stored = try? JSONDecoder().decode(StoredJourney.self, from: data),
              let allStops = stored.snapshot.upcomingStops,
              let destination = allStops.first(where: {
                  $0.sequence == stored.destinationSequence
              }) else { return }
        activeSnapshot = stored.snapshot
        originSequence = stored.originSequence
        destinationSequence = stored.destinationSequence
        stops = allStops.filter {
            $0.sequence >= stored.originSequence
                && $0.sequence <= stored.destinationSequence
        }.sorted { $0.sequence < $1.sequence }
        self.destination = destination
        language = TransitLanguage(rawValue: stored.languageRawValue) ?? .english
        didWarn = stored.didWarn
        didSendFinalWarning = stored.didSendFinalWarning ?? false
        isOutsideRoute = false
        remainingStops = stored.remainingStops
        isTracking = true
        if locationManager.authorizationStatus == .authorizedAlways
            || locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
        startLiveActivity(snapshot: stored.snapshot, destination: destination)
    }

    private func startLiveActivity(
        snapshot: TransitWidgetSnapshot,
        destination: TransitWatchStop
    ) {
        endLiveActivity()

        let targetStop = destinationName(destination)
        let state = StopAlertAttributes.ContentState(
            status: localized("Stop alert active", "落車提示已啟用", "下车提醒已启用"),
            detail: localized(
                "Destination: \(targetStop)",
                "目的地：\(targetStop)",
                "目的地：\(targetStop)"
            ),
            nextStop: localized("Finding next stop", "正在尋找下一站", "正在寻找下一站"),
            remainingStops: remainingStops ?? 0,
            totalStops: max((destinationSequence ?? 0) - (originSequence ?? 0), 1)
        )

        do {
            liveActivity = try Activity.request(
                attributes: StopAlertAttributes(
                    routeNumber: snapshot.routeNumber,
                    targetStop: targetStop
                ),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            liveActivityStatusMessage = nil
        } catch {
            liveActivityStatusMessage = localized(
                "HK Way could not start the Live Activity. Check that Live Activities are enabled in Settings.",
                "HK Way 未能啟動即時動態。請確認已在「設定」中啟用即時動態。",
                "HK Way 未能启动实时活动。请确认已在“设置”中启用实时活动。"
            )
        }
    }

    private func updateLiveActivity(
        remainingStops: Int,
        destination: TransitWatchStop,
        nextStop: String
    ) {
        guard let liveActivity else { return }
        let targetStop = destinationName(destination)
        let state: StopAlertAttributes.ContentState
        switch remainingStops {
        case 0:
            state = .init(
                status: localized("Arriving now", "即將到站", "即将到站"),
                detail: targetStop,
                nextStop: targetStop,
                remainingStops: remainingStops,
                totalStops: max((destinationSequence ?? 0) - (originSequence ?? 0), 1)
            )
        case 1:
            state = .init(
                status: localized("Get off next stop", "下一站落車", "下一站下车"),
                detail: targetStop,
                nextStop: targetStop,
                remainingStops: remainingStops,
                totalStops: max((destinationSequence ?? 0) - (originSequence ?? 0), 1)
            )
        default:
            state = .init(
                status: localized(
                    "\(remainingStops) stops remaining",
                    "尚餘 \(remainingStops) 站",
                    "还剩 \(remainingStops) 站"
                ),
                detail: localized(
                    "Destination: \(targetStop)",
                    "目的地：\(targetStop)",
                    "目的地：\(targetStop)"
                ),
                nextStop: nextStop,
                remainingStops: remainingStops,
                totalStops: max((destinationSequence ?? 0) - (originSequence ?? 0), 1)
            )
        }
        Task { await liveActivity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func updateLiveActivityForOutsideRoute() {
        guard let liveActivity else { return }
        let state = StopAlertAttributes.ContentState(
            status: localized(
                "Away from this route",
                "已離開此路線",
                "已离开此路线"
            ),
            detail: localized(
                "Stop alerts paused",
                "落車提示已暫停",
                "下车提醒已暂停"
            ),
            nextStop: "",
            remainingStops: remainingStops ?? 0,
            totalStops: max((destinationSequence ?? 0) - (originSequence ?? 0), 1)
        )
        Task { await liveActivity.update(ActivityContent(state: state, staleDate: nil)) }
    }


    private func endLiveActivity() {
        let activities = liveActivity.map { [$0] }
            ?? Array(Activity<StopAlertAttributes>.activities)
        for activity in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        self.liveActivity = nil
    }

    private func destinationName(_ stop: TransitWatchStop) -> String {
        switch language {
        case .english: stop.english
        case .traditionalChinese: stop.traditional
        case .simplifiedChinese: stop.simplified
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

    private func sendJourneyStartedNotification(destination: TransitWatchStop) {
        let content = UNMutableNotificationContent()
        switch language {
        case .english:
            content.title = "Stop alert started"
            content.body = "We will remind you before \(destination.english)."
        case .traditionalChinese:
            content.title = "落車提示已啟用"
            content.body = "我們會在到達 \(destination.traditional) 前提醒你。"
        case .simplifiedChinese:
            content.title = "下车提醒已启用"
            content.body = "我们会在到达 \(destination.simplified) 前提醒你。"
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "hkway.stop-alert-started",
                content: content,
                trigger: nil
            )
        )
    }

    private func sendApproachingNotification(destination: TransitWatchStop) {
        let content = UNMutableNotificationContent()
        switch language {
        case .english:
            content.title = "Prepare to get off"
            content.body = "Next stop: \(destination.english)"
        case .traditionalChinese:
            content.title = "準備落車"
            content.body = "下一站：\(destination.traditional)"
        case .simplifiedChinese:
            content.title = "准备下车"
            content.body = "下一站：\(destination.simplified)"
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "hkway.approaching-destination",
                content: content,
                trigger: nil
            )
        )
    }

    private func sendFinalApproachNotification(destination: TransitWatchStop) {
        let content = UNMutableNotificationContent()
        switch language {
        case .english:
            content.title = "Approaching your stop"
            content.body = "About 300 m to \(destination.english)"
        case .traditionalChinese:
            content.title = "即將到達目的地"
            content.body = "距離 \(destination.traditional) 約 300 米"
        case .simplifiedChinese:
            content.title = "即将到达目的地"
            content.body = "距离 \(destination.simplified) 约 300 米"
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "hkway.final-approach-destination",
                content: content,
                trigger: nil
            )
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
