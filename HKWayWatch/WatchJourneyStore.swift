import Foundation
import Observation
import WatchConnectivity
import CoreLocation

@MainActor
@Observable
final class WatchJourneyStore: NSObject, WCSessionDelegate {
    private(set) var journeys: [WatchJourney] = []
    private(set) var lastUpdated: Date?
    var activeJourneyId: String?
    private(set) var originSequences: [String: Int] = [:]
    private(set) var destinationSequences: [String: Int] = [:]

    private let cacheKey = "watchJourneySnapshots.v1"
    private let destinationsCacheKey = "watchJourneyDestinations.v1"
    private let originsCacheKey = "watchJourneyOrigins.v1"
    private let activeJourneyCacheKey = "watchActiveJourneyId.v1"

    override init() {
        super.init()
        loadCache()
        loadDestinationSelections()
        loadOriginSelections()
        activeJourneyId = UserDefaults.standard.string(
            forKey: activeJourneyCacheKey
        )
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        if session.activationState == .activated {
            requestLatestJourneys()
        }
    }

    func select(_ journey: WatchJourney) {
        activeJourneyId = journey.id
        UserDefaults.standard.set(journey.id, forKey: activeJourneyCacheKey)
    }

    func destination(for journey: WatchJourney) -> WatchJourneyStop? {
        guard let sequence = destinationSequences[journey.id] else { return nil }
        return journey.upcomingStops?.first { $0.sequence == sequence }
    }

    func origin(for journey: WatchJourney) -> WatchJourneyStop? {
        let sequence = originSequences[journey.id] ?? journey.boardingSequence
        guard let sequence else { return journey.upcomingStops?.first }
        return journey.upcomingStops?.first { $0.sequence == sequence }
    }

    func hasSelectedOrigin(for journey: WatchJourney) -> Bool {
        originSequences[journey.id] != nil
    }

    func selectOrigin(_ stop: WatchJourneyStop, for journey: WatchJourney) {
        originSequences[journey.id] = stop.sequence
        if let destination = destination(for: journey),
           destination.sequence <= stop.sequence {
            destinationSequences.removeValue(forKey: journey.id)
            saveDestinationSelections()
        }
        saveOriginSelections()
    }

    func selectDestination(_ stop: WatchJourneyStop, for journey: WatchJourney) {
        destinationSequences[journey.id] = stop.sequence
        saveDestinationSelections()
    }

    func stopJourney() {
        activeJourneyId = nil
        UserDefaults.standard.removeObject(forKey: activeJourneyCacheKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(
                  [WatchJourney].self,
                  from: data
              )
        else { return }
        journeys = decoded
    }

    private func loadDestinationSelections() {
        guard let data = UserDefaults.standard.data(forKey: destinationsCacheKey),
              let decoded = try? JSONDecoder().decode(
                  [String: Int].self,
                  from: data
              )
        else { return }
        destinationSequences = decoded
    }

    private func saveDestinationSelections() {
        guard let data = try? JSONEncoder().encode(destinationSequences) else {
            return
        }
        UserDefaults.standard.set(data, forKey: destinationsCacheKey)
    }

    private func loadOriginSelections() {
        guard let data = UserDefaults.standard.data(forKey: originsCacheKey),
              let decoded = try? JSONDecoder().decode(
                  [String: Int].self,
                  from: data
              )
        else { return }
        originSequences = decoded
    }

    private func saveOriginSelections() {
        guard let data = try? JSONEncoder().encode(originSequences) else {
            return
        }
        UserDefaults.standard.set(data, forKey: originsCacheKey)
    }

    private func accept(_ context: [String: Any]) {
        if context["stopJourney"] as? Bool == true {
            stopJourney()
            return
        }
        if let data = context["activeJourney"] as? Data,
           let journey = try? JSONDecoder().decode(
               WatchJourney.self,
               from: data
           ),
           let originSequence = context["activeOriginSequence"] as? Int,
           let destinationSequence = context["activeDestinationSequence"] as? Int {
            journeys = [journey]
            originSequences[journey.id] = originSequence
            destinationSequences[journey.id] = destinationSequence
            activeJourneyId = journey.id
            UserDefaults.standard.set(
                journey.id,
                forKey: activeJourneyCacheKey
            )
            lastUpdated = Date()
            if let cacheData = try? JSONEncoder().encode([journey]) {
                UserDefaults.standard.set(cacheData, forKey: cacheKey)
            }
            saveOriginSelections()
            saveDestinationSelections()
            return
        }

        guard let data = context["etaSnapshots"] as? Data,
              let decoded = try? JSONDecoder().decode(
                  [WatchJourney].self,
                  from: data
              )
        else { return }
        journeys = decoded
        lastUpdated = Date()
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func requestLatestJourneys() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if session.isReachable {
            session.sendMessage(
                ["requestSnapshots": true],
                replyHandler: { [weak self] reply in
                    Task { @MainActor in self?.accept(reply) }
                },
                errorHandler: nil
            )
        } else {
            session.transferUserInfo(["requestSnapshots": true])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.accept(context)
            self.requestLatestJourneys()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in self.accept(applicationContext) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in self.accept(userInfo) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in self.accept(message) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in self.requestLatestJourneys() }
    }
}
