import SwiftUI

struct TramView: View {
    let requiredEnglishStopName: String?

    @Environment(\.transitLanguage)
    private var transitLanguage

    @State
    private var dataset: TramDataset?

    @State
    private var loadError: Error?

    init(requiredEnglishStopName: String? = nil) {
        self.requiredEnglishStopName = requiredEnglishStopName
    }

    var body: some View {
        Group {
            if let dataset {
                routeList(dataset.routes)
            } else if loadError != nil {
                ContentUnavailableView {
                    Label("Unable to Load Tram Routes", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("The bundled and saved tram data could not be read.")
                } actions: {
                    Button("Try Again") {
                        loadError = nil
                        Task { await loadDataset() }
                    }
                }
            } else {
                ProgressView("Loading tram routes…")
            }
        }
        .navigationTitle(
            Text(requiredEnglishStopName == nil ? "Tram" : "Happy Valley Tram Routes")
        )
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard dataset == nil, loadError == nil else { return }
            await loadDataset()
        }
    }

    private func routeList(_ routes: [TramRoute]) -> some View {
        let displayedRoutes = routes.filter { route in
            guard let requiredEnglishStopName else { return true }
            return route.directions.contains { direction in
                direction.stops.contains { stop in
                    stop.nameEnglish.localizedCaseInsensitiveContains(
                        requiredEnglishStopName
                    )
                }
            }
        }

        return ScrollView {
            LazyVStack(spacing: 12) {
                if requiredEnglishStopName != nil {
                    Label(
                        "Only tram routes serving Happy Valley are shown.",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }

                ForEach(displayedRoutes) { route in
                    NavigationLink {
                        TramRouteDetailView(route: route)
                    } label: {
                        routeCard(route)
                    }
                    .buttonStyle(.plain)
                }

                Link(
                    destination: URL(
                        string: "https://www.hktramways.com/en/schedules-fares/en/schedules-fares"
                    )!
                ) {
                    Label("Official Schedules and Fares", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .customInfoCardSurface(cornerRadius: 22)
                }
                .foregroundStyle(.primary)

                Label(
                    "Live tram arrivals are not currently available through a documented public API.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding()
        }
    }

    private func routeCard(_ route: TramRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "tram.fill")
                    .font(.title2)
                    .frame(width: 32)

                Text(route.name(for: transitLanguage))
                    .font(.headline)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(
                    "\(route.directions.first?.journeyTime ?? 0) min",
                    systemImage: "clock"
                )
                Label(
                    route.fare.formatted(.currency(code: "HKD")),
                    systemImage: "dollarsign.circle"
                )
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    @MainActor
    private func loadDataset() async {
        do {
            dataset = try TramDatasetService.loadOffline()
            loadError = nil
        } catch {
            loadError = error
            return
        }

        do {
            dataset = try await TramDatasetService.refresh()
        } catch {
            // Keep showing the bundled or saved snapshot when offline or when
            // an official refresh cannot be decoded.
        }
    }
}

private struct TramRouteDetailView: View {
    let route: TramRoute

    @Environment(\.transitLanguage)
    private var transitLanguage

    @State
    private var selectedDirectionID: Int

    init(route: TramRoute) {
        self.route = route
        _selectedDirectionID = State(
            initialValue: route.directions.first?.id ?? 1
        )
    }

    private var selectedDirection: TramDirection? {
        route.directions.first { $0.id == selectedDirectionID }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 22) {
                    if route.directions.count > 1 {
                        Picker(
                            "Direction",
                            selection: $selectedDirectionID
                        ) {
                            ForEach(route.directions) { direction in
                                Text(
                                    direction.destination(
                                        for: transitLanguage
                                    )
                                )
                                .tag(direction.id)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        CustomInfoCardView(title: "Journey Time") {
                            Text(
                                "\(selectedDirection?.journeyTime ?? 0) min"
                            )
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        }

                        CustomInfoCardView(title: "Adult Fare") {
                            Text(
                                route.fare.formatted(
                                    .currency(code: "HKD")
                                )
                            )
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(
                EdgeInsets(
                    top: 8,
                    leading: 0,
                    bottom: 8,
                    trailing: 0
                )
            )
            .listRowSeparator(.hidden)

            Section("Stops") {
                let stops = selectedDirection?.stops ?? []

                ForEach(Array(stops.enumerated()), id: \.element.id) {
                    index, stop in
                    HStack(alignment: .top, spacing: 12) {
                        CustomStopLineView(
                            sequence: stop.sequence,
                            isFirst: index == 0,
                            isLast: index == stops.count - 1,
                            operatorIds: ["TRAM"]
                        )

                        Text(stop.name(for: transitLanguage))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 14)
                    }
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: 16,
                            bottom: 0,
                            trailing: 16
                        )
                    )
                    .listRowSeparator(.hidden)
                }
            }
        }
        .navigationTitle(route.name(for: transitLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TramView()
    }
}
