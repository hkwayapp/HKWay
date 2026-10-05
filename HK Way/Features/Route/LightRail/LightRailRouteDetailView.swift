import SwiftUI

struct LightRailRouteStopSelection: Identifiable, Hashable {
    let stop: LightRailStop
    let destination: LightRailStop?
    let circular: Bool
    let fareDestinations: [LightRailStop]

    var id: Int { stop.stationID }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct LightRailRouteDetailView: View {
    let route: LightRailRoute
    var onSelectStop: ((LightRailRouteStopSelection) -> Void)?
    @Environment(\.transitLanguage) private var language
    @State private var journeys: [LightRailJourney] = []
    @State private var selectedDirection = "1"
    @State private var selectedStop: LightRailRouteStopSelection?
    @State private var failed = false

    private var journey: LightRailJourney? {
        journeys.first { $0.id == selectedDirection } ?? journeys.first
    }

    var body: some View {
        Group {
            if failed {
                ContentUnavailableView("Unable to Load Light Rail Stops", systemImage: "tram.fill")
            } else if let journey {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let origin = journey.stops.first,
                           let destination = journey.stops.last {
                            CustomRouteDetailedBanner(
                                routeNumber: route.id,
                                origin: name(origin),
                                destination: name(destination),
                                routeBadgeColor: route.color,
                                routeBadgeTextColor: route.usesDarkText ? .black : .white
                            )
                        }

                        if journeys.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Direction").font(.headline)
                                Picker("Direction", selection: $selectedDirection) {
                                    ForEach(journeys) { option in
                                        Text(option.stops.last.map(name) ?? option.id).tag(option.id)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .tint(.primary)
                            }
                        } else {
                            Label("Circular Route", systemImage: "arrow.triangle.2.circlepath")
                                .font(.headline)
                        }

                        Text("Stops").font(.headline).foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            ForEach(journey.stops.indices, id: \.self) { index in
                                let stop = journey.stops[index]
                                HStack(spacing: 16) {
                                    CustomStopLineView(
                                        sequence: index + 1,
                                        isFirst: index == 0,
                                        isLast: index == journey.stops.count - 1,
                                        routeColor: route.color
                                    )
                                    VStack(alignment: .leading, spacing: 0) {
                                        Button {
                                            let selection = LightRailRouteStopSelection(
                                                stop: stop,
                                                destination: journey.stops.last,
                                                circular: journey.id == "loop",
                                                fareDestinations: journey.destinations(after: index)
                                            )
                                            if let onSelectStop {
                                                onSelectStop(selection)
                                            } else {
                                                selectedStop = selection
                                            }
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(name(stop)).font(.body)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                            .padding(.vertical, 10)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        if let code = stop.tuenMaStationCode {
                                            TuenMaInterchangeLink(stationCode: code)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.bottom, 8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 16)
                            }
                        }
                        .customInfoCardSurface(cornerRadius: 22)

                        Text("Tap a stop for live arrivals and platform information from MTR.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
            } else {
                ProgressView("Loading Light Rail Stops…")
            }
        }
        .foregroundStyle(.primary)
        .background(route.color.opacity(0.10).ignoresSafeArea())
        .navigationTitle(route.id)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedStop) { selection in
            LightRailStopETAView(
                route: route,
                stop: selection.stop,
                destination: selection.destination,
                circular: selection.circular,
                fareDestinations: selection.fareDestinations
            )
        }
        .task(id: route.id) {
            guard journeys.isEmpty else { return }
            do {
                journeys = try LightRailStops.load(routeID: route.id)
                if !journeys.contains(where: { $0.id == selectedDirection }) {
                    selectedDirection = journeys.first?.id ?? "1"
                }
            } catch { failed = true }
        }
    }

    private func name(_ stop: LightRailStop) -> String {
        switch language {
        case .english: stop.english
        case .traditionalChinese: stop.traditional
        case .simplifiedChinese: stop.simplified
        }
    }
}
