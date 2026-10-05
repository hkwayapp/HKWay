import SwiftData
import SwiftUI

struct BuddhaBusRoutesView: View {
    @Query private var candidates: [RouteEntity]

    init() {
        let numbers = ["2", "21", "23"]
        let predicate = #Predicate<RouteEntity> { numbers.contains($0.number) }
        _candidates = Query(filter: predicate, sort: \RouteEntity.number)
    }

    @State private var matches: [RouteEntity] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading connecting routes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        Text("Selected NLB routes with Ngong Ping as a dataset endpoint. This list is not exhaustive and does not plan the final approach to the attraction.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Section("Direct / Terminates Here") {
                        if matches.isEmpty {
                            ContentUnavailableView("No Connecting Routes", systemImage: "bus.fill",
                                                   description: Text("Update the dataset and try again."))
                        } else {
                            ForEach(matches) { route in
                                NavigationLink {
                                    RouteDetailView(route: route)
                                } label: {
                                    RouteRowView(route: route, etaResult: nil, isCompact: true,
                                                 allowsTwoLineOrigin: true, allowsTwoLineDestination: true,
                                                 allowsFullNameWrapping: true, usesUniformNameStyle: true)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                    Section {
                        Link("New Lantao Bus — Routes & Timetables", destination: URL(string: "https://www.nlb.com.hk/route")!)
                            .foregroundStyle(.primary)
                    } footer: {
                        Text("Check operating days, return departures and current fares with NLB. A listed route does not mean a bus is running now.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(red: 0.57, green: 0.38, blue: 0.16).opacity(0.10).ignoresSafeArea())
        .navigationTitle("Bus Routes to Ngong Ping")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: candidates.map(\.id)) {
            isLoading = true
            await Task.yield()
            guard !Task.isCancelled else { return }
            matches = candidates.filter { route in
                let endpoints = route.journeys.flatMap { journey in
                    let stops = journey.journeyStops.sorted { $0.sequence < $1.sequence }
                    return [stops.first?.stop?.id, stops.last?.stop?.id].compactMap { $0 }
                }
                return BuddhaBusConnection.matches(number: route.number,
                                                    operatorIDs: route.operators.map(\.id), endpointIDs: endpoints)
            }.sorted { $0.number.localizedStandardCompare($1.number) == .orderedAscending }
            isLoading = false
        }
    }
}
