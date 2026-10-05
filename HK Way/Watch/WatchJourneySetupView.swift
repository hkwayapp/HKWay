import SwiftUI
import CoreLocation

struct WatchJourneySetupView: View {
    let route: RouteEntity
    let journeys: [JourneyEntity]
    let language: TransitLanguage
    let userLocation: CLLocation?
    let onStart: (TransitWidgetSnapshot, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var journeyID: String?
    @State private var originSequence: Int?
    @State private var destinationSequence: Int?
    @State private var showOutsideRouteWarning = false

    private var selectedJourney: JourneyEntity? {
        journeys.first { $0.id == journeyID }
    }

    private var stops: [JourneyStopEntity] {
        selectedJourney?.journeyStops
            .filter { $0.stop != nil }
            .sorted { $0.sequence < $1.sequence } ?? []
    }

    private var destinationStops: [JourneyStopEntity] {
        guard let originSequence else { return [] }
        return stops.filter { $0.sequence > originSequence }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    if journeys.count > 1 {
                        Picker(localized("Direction", "方向", "方向"), selection: $journeyID) {
                            ForEach(journeys) { journey in
                                Text(directionLabel(journey))
                                    .tag(Optional(journey.id))
                            }
                        }
                        .onChange(of: journeyID) { _, _ in
                            configureStops()
                        }
                    }

                    Section {
                        Picker(localized("Get off at", "落車", "下车"), selection: $destinationSequence) {
                            Text(localized("Select destination", "選擇落車站", "选择下车站"))
                                .tag(Int?.none)
                            ForEach(destinationStops) { journeyStop in
                                Text(stopName(journeyStop))
                                    .tag(Optional(journeyStop.sequence))
                            }
                        }
                    } footer: {
                        Text(
                            localized(
                                "You’ll be alerted one stop before your destination.",
                                "到達目的地前一站時會通知你。",
                                "到达目的地前一站时会通知你。"
                            )
                        )
                    }
                }

                Button {
                    requestStartJourney()
                } label: {
                    Label(
                        localized(
                            "Start Journey",
                            "開始行程",
                            "开始行程"
                        ),
                        systemImage: "bell.fill"
                    )
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
                .disabled(originSequence == nil || destinationSequence == nil)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.bar)
            }
            .navigationTitle(
                localized(
                    "Route \(route.number)",
                    "路線 \(route.number)",
                    "路线 \(route.number)"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("Cancel", "取消", "取消")) { dismiss() }
                }
            }
            .onAppear {
                if journeyID == nil {
                    journeyID = journeys.max {
                        $0.journeyStops.count < $1.journeyStops.count
                    }?.id
                }
                configureStops()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .alert(
            localized("Away from this route", "你似乎唔喺呢條路線附近", "您似乎不在这条路线附近"),
            isPresented: $showOutsideRouteWarning
        ) {
            Button(localized("Review journey", "重新查看行程", "重新查看行程"), role: .cancel) {}
            Button(localized("Start anyway", "仍然開始", "仍然开始")) {
                startJourneyNow()
            }
        } message: {
            Text(localized(
                "You are more than 1 km from every stop on this route. Stop reminders may not be accurate until you are closer.",
                "你距離呢條路線所有車站超過 1 公里。靠近路線前，落車提示可能唔準確。",
                "您距离这条路线所有车站超过 1 公里。靠近路线前，下车提醒可能不准确。"
            ))
        }
    }

    private func configureStops() {
        let orderedStops = stops
        guard !orderedStops.isEmpty else {
            originSequence = nil
            destinationSequence = nil
            return
        }

        if let userLocation {
            let distances: [(sequence: Int, distance: CLLocationDistance)] =
                orderedStops.compactMap { item -> (Int, CLLocationDistance)? in
                guard let stop = item.stop,
                      stop.latitude != 0 || stop.longitude != 0 else { return nil }
                let location = CLLocation(
                    latitude: stop.latitude,
                    longitude: stop.longitude
                )
                return (item.sequence, userLocation.distance(from: location))
            }
            originSequence = distances.min {
                $0.distance < $1.distance
            }?.sequence
        } else {
            originSequence = orderedStops.first?.sequence
        }
        destinationSequence = nil
    }

    private var isMoreThanOneKilometreFromRoute: Bool {
        guard let userLocation else { return false }
        var closestDistance: CLLocationDistance?
        for item in stops {
            guard let stop = item.stop,
                  stop.latitude != 0 || stop.longitude != 0 else { continue }
            let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
            let distance = userLocation.distance(from: stopLocation)
            if closestDistance == nil || distance < closestDistance! {
                closestDistance = distance
            }
        }
        guard let closestDistance else { return false }
        return closestDistance > 1_000
    }

    private func requestStartJourney() {
        if isMoreThanOneKilometreFromRoute {
            showOutsideRouteWarning = true
        } else {
            startJourneyNow()
        }
    }

    private func startJourneyNow() {
        guard let journey = selectedJourney,
              let originSequence,
              let destinationSequence,
              let origin = stops.first(where: { $0.sequence == originSequence })
        else { return }

        let snapshot = TransitWidgetSnapshot(
            route: route,
            journey: journey,
            journeyStop: origin,
            references: []
        )
        onStart(snapshot, originSequence, destinationSequence)
        dismiss()
    }

    private func stopName(_ journeyStop: JourneyStopEntity) -> String {
        journeyStop.stop?.displayName(for: language)
            ?? localized("Unknown stop", "未知車站", "未知车站")
    }

    private func directionLabel(_ journey: JourneyEntity) -> String {
        let ordered = journey.journeyStops.sorted { $0.sequence < $1.sequence }
        let origin = ordered.first.flatMap { $0.stop?.displayName(for: language) }
            ?? route.displayOrigin(for: language)
        let destination = ordered.last.flatMap { $0.stop?.displayName(for: language) }
            ?? route.displayDestination(for: language)
        return "\(origin) → \(destination)"
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
