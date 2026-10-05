import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity

@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func syncSnapshots(_ snapshots: [TransitWidgetSnapshot]) {
        guard WCSession.isSupported(),
              let data = try? JSONEncoder().encode(snapshots)
        else { return }

        let context: [String: Any] = [
            "etaSnapshots": data,
            "sentAt": Date().timeIntervalSince1970
        ]
        let session = WCSession.default
        try? session.updateApplicationContext(context)
        session.transferUserInfo(context)
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    func startJourney(
        _ snapshot: TransitWidgetSnapshot,
        originSequence: Int,
        destinationSequence: Int
    ) {
        guard WCSession.isSupported(),
              let data = try? JSONEncoder().encode(snapshot) else { return }

        let command: [String: Any] = [
            "activeJourney": data,
            "activeOriginSequence": originSequence,
            "activeDestinationSequence": destinationSequence,
            "sentAt": Date().timeIntervalSince1970
        ]
        let session = WCSession.default
        try? session.updateApplicationContext(command)
        session.transferUserInfo(command)
        if session.isReachable {
            session.sendMessage(command, replyHandler: nil, errorHandler: nil)
        }
    }

    func stopJourney() {
        guard WCSession.isSupported() else { return }
        let command: [String: Any] = [
            "stopJourney": true,
            "sentAt": Date().timeIntervalSince1970
        ]
        let session = WCSession.default
        try? session.updateApplicationContext(command)
        session.transferUserInfo(command)
        if session.isReachable {
            session.sendMessage(command, replyHandler: nil, errorHandler: nil)
        }
    }

    private func snapshotReply() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(
            TransitWidgetSnapshotStore.load()
        ) else { return [:] }
        return [
            "etaSnapshots": data,
            "sentAt": Date().timeIntervalSince1970
        ]
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.syncSnapshots(TransitWidgetSnapshotStore.load())
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message["requestSnapshots"] as? Bool == true else {
            replyHandler([:])
            return
        }
        Task { @MainActor in
            replyHandler(self.snapshotReply())
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard message["requestSnapshots"] as? Bool == true else { return }
        Task { @MainActor in
            self.syncSnapshots(TransitWidgetSnapshotStore.load())
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard userInfo["requestSnapshots"] as? Bool == true else { return }
        Task { @MainActor in
            self.syncSnapshots(TransitWidgetSnapshotStore.load())
        }
    }
}
#else
@MainActor
final class WatchSyncManager {
    static let shared = WatchSyncManager()
    func activate() {}
    func syncSnapshots(_ snapshots: [TransitWidgetSnapshot]) {}
    func startJourney(
        _ snapshot: TransitWidgetSnapshot,
        originSequence: Int,
        destinationSequence: Int
    ) {}
    func stopJourney() {}
}
#endif
