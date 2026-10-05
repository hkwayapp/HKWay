import SwiftUI
import WatchKit
import CoreLocation

struct WatchJourneyListView: View {
    @Environment(WatchJourneyStore.self) private var store

    private var routeChoices: [WatchJourney] {
        Dictionary(grouping: store.journeys, by: \.routeNumber)
            .compactMap { _, journeys in
                journeys.max {
                    ($0.upcomingStops?.count ?? 0)
                        < ($1.upcomingStops?.count ?? 0)
                }
            }
            .sorted {
                $0.routeNumber.localizedStandardCompare($1.routeNumber)
                    == .orderedAscending
            }
    }

    private var activeJourney: WatchJourney? {
        guard let id = store.activeJourneyId else { return nil }
        return store.journeys.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let activeJourney {
                    WatchJourneyDetailView(journey: activeJourney)
                } else {
                    WatchWelcomeView()
                }
            }
            .navigationTitle("HK Way")
        }
    }
}

struct WatchJourneyDetailView: View {
    @Environment(WatchJourneyStore.self) private var store
    @State private var locator = WatchStopLocator()
    @State private var tracker = WatchJourneyTracker()
    @State private var attemptedAutomaticOrigin = false
    let journey: WatchJourney

    private var isActive: Bool { store.activeJourneyId == journey.id }
    private var selectedDestination: WatchJourneyStop? {
        store.destination(for: journey)
    }
    private var selectedOrigin: WatchJourneyStop? {
        store.origin(for: journey)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                WatchRouteHeader(journey: journey, isActive: isActive)
                WatchJourneyQuickInfoView(
                    journey: journey,
                    origin: selectedOrigin,
                    destination: selectedDestination,
                    isActive: isActive
                )
            if !isActive,
               let stops = journey.upcomingStops,
               !stops.isEmpty {
                    NavigationLink {
                        StopSelectionView(
                            journey: journey,
                            stops: stops,
                            mode: .origin
                        )
                    } label: {
                        SelectionButtonLabel(
                            title: "Board at",
                            value: locator.isLocating
                                ? "Finding nearest stop…"
                                : (selectedOrigin?.name ?? "Choose boarding stop"),
                            systemImage: "location.circle.fill",
                            action: selectedOrigin == nil || locator.isLocating
                                ? nil
                                : "Change"
                        )
                    }

                    NavigationLink {
                        StopSelectionView(
                            journey: journey,
                            stops: stops.filter {
                                $0.sequence > (selectedOrigin?.sequence ?? Int.min)
                            },
                            mode: .destination
                        )
                    } label: {
                        SelectionButtonLabel(
                            title: "Get off at",
                            value: selectedDestination?.name ?? "Choose destination",
                            systemImage: "flag.checkered.circle.fill"
                        )
                    }
            }

            Button(isActive ? "End Journey" : "Start Journey") {
                if isActive {
                    tracker.stop()
                    store.stopJourney()
                } else {
                    store.select(journey)
                    beginTracking()
                    WKInterfaceDevice.current().play(.start)
                }
            }
            .fontWeight(.semibold)
            .tint(isActive ? .red : .blue)
            .disabled(!isActive && (selectedOrigin == nil || selectedDestination == nil))

            if isActive {
                ActiveJourneyStatusView(
                    tracker: tracker,
                    destination: selectedDestination
                )
            } else {
                Text("Choose where you board and get off, then start your journey.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle("Route \(journey.routeNumber)")
        .onAppear {
            if isActive, !tracker.isTracking {
                beginTracking()
            }
            guard !attemptedAutomaticOrigin,
                  !store.hasSelectedOrigin(for: journey),
                  let stops = journey.upcomingStops,
                  !stops.isEmpty
            else { return }

            attemptedAutomaticOrigin = true
            locator.selectNearest(from: stops) { stop in
                guard let stop else { return }
                store.selectOrigin(stop, for: journey)
                WKInterfaceDevice.current().play(.success)
            }
        }
        .onDisappear {
            if !isActive {
                tracker.stop()
            }
        }
    }

    private func beginTracking() {
        guard let stops = journey.upcomingStops,
              let origin = selectedOrigin,
              let destination = selectedDestination else { return }
        tracker.start(stops: stops, origin: origin, destination: destination)
    }
}

private struct WatchWelcomeView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bus.fill")
                .font(.system(size: 31, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(.blue.gradient, in: Circle())

            VStack(spacing: 5) {
                Text("Ready to ride")
                    .font(.headline)
                Text("Pick a favourite route on your iPhone. Your journey will appear here, ready for the next stop.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Label("Open HK Way on iPhone", systemImage: "iphone")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.blue)
                .padding(.top, 2)
        }
        .padding(.horizontal, 10)
    }
}

private struct WatchRouteHeader: View {
    let journey: WatchJourney
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                Text(journey.routeNumber)
                    .font(.title.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(.white)
                    .frame(minWidth: 59, minHeight: 51)
                    .padding(.horizontal, 6)
                    .background(isActive ? Color.green : Color.blue, in: RoundedRectangle(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        isActive ? "Journey in progress" : "Ready to start",
                        systemImage: isActive ? "location.fill" : "bus.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? .green : .blue)

                    Text("To " + journey.destination)
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            if let arrival = journey.futureArrivals.first {
                Label {
                    Text("Next bus " + arrival.formatted(.relative(presentation: .named)))
                } icon: {
                    Image(systemName: "clock.fill")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 19))
    }
}

private struct WatchJourneyQuickInfoView: View {
    let journey: WatchJourney
    let origin: WatchJourneyStop?
    let destination: WatchJourneyStop?
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(origin?.name ?? journey.boardingStop, systemImage: "location.circle.fill")
                .font(.caption.weight(.medium))
                .lineLimit(1)

            HStack(spacing: 7) {
                Image(systemName: "arrow.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(.secondary.opacity(0.35))
                    .frame(height: 1)
            }
            .padding(.leading, 4)

            Label(destination?.name ?? "Choose destination", systemImage: "flag.checkered.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(destination == nil ? .secondary : .primary)
                .lineLimit(1)

            if isActive {
                Text("Live journey tracking is on")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ActiveJourneyStatusView: View {
    let tracker: WatchJourneyTracker
    let destination: WatchJourneyStop?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: tracker.statusIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tracker.hasArrived ? .green : .orange)
                Text(tracker.statusText)
                    .font(.headline)
                    .lineLimit(2)
            }

            if tracker.hasArrived {
                Text("You have reached " + (destination?.name ?? "your stop"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(tracker.remainingStops)")
                        .font(.title3.bold().monospacedDigit())
                    Text(tracker.remainingStops == 1 ? "stop remaining" : "stops remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                if let stopName = tracker.nearestStop?.name {
                    Label("Near " + stopName, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
#if DEBUG
            if tracker.isTracking {
                Button("Test notification in 5 sec") {
                    WatchNotificationManager.shared.requestAuthorization()
                    WatchNotificationManager.shared.send(
                        title: "下一站落車 · Get off next stop",
                        body: "荃灣西 · Tsuen Wan West",
                        delay: 5
                    )
                }
                .font(.caption)
                Button("Simulate next stop") {
                    tracker.simulateNextStopWarning()
                }
                .font(.caption)
                Button("Simulate arrival") {
                    tracker.simulateArrival()
                }
                .font(.caption)
            }
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            tracker.hasArrived ? .green.opacity(0.16) : .orange.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

private struct SelectionButtonLabel: View {
    let title: String
    let value: String
    let systemImage: String
    var action: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            if let action {
                Text(action)
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
    }
}

private enum StopSelectionMode {
    case origin
    case destination
}

private struct StopSelectionView: View {
    @Environment(WatchJourneyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var locator = WatchStopLocator()

    let journey: WatchJourney
    let stops: [WatchJourneyStop]
    let mode: StopSelectionMode

    var body: some View {
        List {
            if mode == .origin {
                Button {
                    locator.selectNearest(from: stops) { stop in
                        guard let stop else { return }
                        store.selectOrigin(stop, for: journey)
                        WKInterfaceDevice.current().play(.success)
                        dismiss()
                    }
                } label: {
                    Label(
                        locator.isLocating ? "Finding nearest stop…" : "Use Current Location",
                        systemImage: "location.fill"
                    )
                }
                .disabled(locator.isLocating)

                if let errorMessage = locator.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            ForEach(stops, id: \.sequence) { stop in
                Button {
                    if mode == .origin {
                        store.selectOrigin(stop, for: journey)
                    } else {
                        store.selectDestination(stop, for: journey)
                    }
                    WKInterfaceDevice.current().play(.click)
                    dismiss()
                } label: {
                    HStack {
                        Text(stop.name)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        if isSelected(stop) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        .navigationTitle(mode == .origin ? "Origin" : "Destination")
    }

    private func isSelected(_ stop: WatchJourneyStop) -> Bool {
        switch mode {
        case .origin:
            store.origin(for: journey)?.sequence == stop.sequence
        case .destination:
            store.destination(for: journey)?.sequence == stop.sequence
        }
    }
}

@MainActor
@Observable
private final class WatchStopLocator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var stops: [WatchJourneyStop] = []
    private var completion: ((WatchJourneyStop?) -> Void)?

    var isLocating = false
    var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func selectNearest(
        from stops: [WatchJourneyStop],
        completion: @escaping (WatchJourneyStop?) -> Void
    ) {
        self.stops = stops
        self.completion = completion
        errorMessage = nil
        isLocating = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            fail("Allow location access in Watch Settings.")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                self.fail("Allow location access in Watch Settings.")
            default:
                break
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let nearest = self.stops.compactMap { stop -> (WatchJourneyStop, CLLocationDistance)? in
                guard let latitude = stop.latitude,
                      let longitude = stop.longitude,
                      latitude != 0 || longitude != 0 else { return nil }
                let stopLocation = CLLocation(latitude: latitude, longitude: longitude)
                return (stop, location.distance(from: stopLocation))
            }.min { $0.1 < $1.1 }?.0

            self.isLocating = false
            self.completion?(nearest)
            self.completion = nil
            if nearest == nil {
                self.errorMessage = "No stop coordinates are available."
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in self.fail("Unable to get your location.") }
    }

    private func fail(_ message: String) {
        isLocating = false
        errorMessage = message
        completion?(nil)
        completion = nil
    }
}

@MainActor
@Observable
private final class WatchJourneyTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var journeyStops: [WatchJourneyStop] = []
    private var destination: WatchJourneyStop?
    private var warnedForNextStop = false

    var isTracking = false
    var hasArrived = false
    var nearestStop: WatchJourneyStop?
    var remainingStops = 0
    var statusText = "Locating…"
    var statusIcon = "location.fill"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 15
        manager.activityType = .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = true
    }

    func start(
        stops: [WatchJourneyStop],
        origin: WatchJourneyStop,
        destination: WatchJourneyStop
    ) {
        journeyStops = stops.filter {
            $0.sequence >= origin.sequence && $0.sequence <= destination.sequence
        }.sorted { $0.sequence < $1.sequence }
        self.destination = destination
        WatchNotificationManager.shared.requestAuthorization()
        remainingStops = max(journeyStops.count - 1, 0)
        warnedForNextStop = false
        hasArrived = false
        statusText = "Locating…"
        statusIcon = "location.fill"
        isTracking = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            statusText = "Location unavailable"
            statusIcon = "location.slash"
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        isTracking = false
    }

#if DEBUG
    func simulateNextStopWarning() {
        remainingStops = 1
        statusText = "Get off next stop"
        statusIcon = "bell.fill"
        if !warnedForNextStop {
            warnedForNextStop = true
            WKInterfaceDevice.current().play(.notification)
        }
    }

    func simulateArrival() {
        remainingStops = 0
        hasArrived = true
        statusText = "Arrived · Get off"
        statusIcon = "flag.checkered"
        stop()
    }
#endif

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                if self.isTracking { manager.startUpdatingLocation() }
            case .denied, .restricted:
                self.statusText = "Location unavailable"
                self.statusIcon = "location.slash"
            default:
                break
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
    ) {
        Task { @MainActor in
            self.statusText = "Waiting for location…"
            self.statusIcon = "location.magnifyingglass"
        }
    }

    private func update(using location: CLLocation) {
        let candidates = journeyStops.compactMap {
            stop -> (stop: WatchJourneyStop, distance: CLLocationDistance)? in
            guard let latitude = stop.latitude,
                  let longitude = stop.longitude,
                  latitude != 0 || longitude != 0 else { return nil }
            return (
                stop,
                location.distance(from: CLLocation(
                    latitude: latitude,
                    longitude: longitude
                ))
            )
        }
        guard let nearest = candidates.min(by: { $0.distance < $1.distance }) else {
            statusText = "No stop locations"
            statusIcon = "exclamationmark.triangle"
            return
        }

        // Ignore distant GPS positions so a bad simulator/default location does
        // not advance the journey to an unrelated stop.
        guard nearest.distance <= 400 else {
            statusText = "Travelling"
            statusIcon = "location.fill"
            return
        }

        nearestStop = nearest.stop
        guard let destination,
              let destinationIndex = journeyStops.firstIndex(of: destination),
              let currentIndex = journeyStops.firstIndex(of: nearest.stop)
        else { return }

        remainingStops = max(destinationIndex - currentIndex, 0)

        if currentIndex >= destinationIndex || nearest.stop.sequence == destination.sequence {
            hasArrived = true
            statusText = "Arrived · Get off"
            statusIcon = "flag.checkered"
            stop()
        } else if remainingStops == 1 {
            statusText = "Get off next stop"
            statusIcon = "bell.fill"
            if !warnedForNextStop {
                warnedForNextStop = true
            }
        } else {
            statusText = "Journey active"
            statusIcon = "location.fill"
        }
    }

}
