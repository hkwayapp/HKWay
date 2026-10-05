import SwiftData
import SwiftUI

struct TszShanMonasteryBusRoutesView: View {
    @Query private var candidates: [RouteEntity]
    @State private var directRoutes: [RouteEntity] = []
    @State private var nearbyRoutes: [RouteEntity] = []
    @State private var isLoading = true

    init() {
        let numbers = ["20T", "20B", "20C", "75K", "275R"]
        let predicate = #Predicate<RouteEntity> { numbers.contains($0.number) }
        _candidates = Query(filter: predicate, sort: \RouteEntity.number)
    }

    var body: some View {
        List {
            Section {
                Text("Routes are classified from the monastery's official directions and matched by route number and operator in HK Way's open transport dataset. Check the selected direction and current operating information before travelling.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Direct Limited Service") {
                if isLoading {
                    ProgressView("Loading connecting routes…")
                        .frame(maxWidth: .infinity, minHeight: 70)
                } else if directRoutes.isEmpty {
                    unavailableRoutes
                } else {
                    ForEach(directRoutes) { routeRow($0, limited: true) }
                }
            }

            Section("Nearby Services — Onward Walk Required") {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 50)
                } else if nearbyRoutes.isEmpty {
                    unavailableRoutes
                } else {
                    ForEach(nearbyRoutes) { routeRow($0, limited: $0.number == "275R") }
                }
            }

            Section("Other Official Connection") {
                Text("Resident service NR532 is listed on the monastery's official directions page but is not available as an in-app route in the current open transport dataset.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                officialDirectionsLink
            }

            Section {
                Text("A listed route does not mean it is running now. Route 20T operates on Mondays to Fridays except public holidays; route 275R operates on Sundays and public holidays. HK Way does not provide live arrivals on this connection list.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.52, green: 0.36, blue: 0.20).opacity(0.10).ignoresSafeArea())
        .navigationTitle("Bus Routes to Tsz Shan Monastery")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: candidates.map(\.id)) {
            isLoading = true
            await Task.yield()
            guard !Task.isCancelled else { return }

            directRoutes = matchingRoutes(kind: .directLimited)
            nearbyRoutes = matchingRoutes(kind: .nearby)
            isLoading = false
        }
    }

    @ViewBuilder
    private func routeRow(_ route: RouteEntity, limited: Bool) -> some View {
        NavigationLink {
            RouteDetailView(route: route)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RouteRowView(
                    route: route,
                    etaResult: nil,
                    isCompact: true,
                    allowsTwoLineOrigin: true,
                    allowsTwoLineDestination: true,
                    allowsFullNameWrapping: true,
                    usesUniformNameStyle: true
                )
                if limited {
                    Text(route.number == "20T" ? "Weekdays except public holidays" : "Sundays and public holidays")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brown.opacity(0.16), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }

    private var unavailableRoutes: some View {
        ContentUnavailableView(
            "No Connecting Routes",
            systemImage: "bus.fill",
            description: Text("Update the dataset and try again.")
        )
    }

    private var officialDirectionsLink: some View {
        Link(destination: URL(string: "https://www.tszshan.org/home/new/en/visit.php#transaction")!) {
            Label("Official Getting Here Information", systemImage: "arrow.up.right.square")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .foregroundStyle(.primary)
    }

    private func matchingRoutes(kind: TszShanMonasteryBusConnection.Kind) -> [RouteEntity] {
        candidates.filter { route in
            TszShanMonasteryBusConnection.kind(
                number: route.number,
                operatorIDs: route.operators.map(\.id)
            ) == kind
        }
        .sorted {
            let numberOrder = $0.number.localizedStandardCompare($1.number)
            return numberOrder == .orderedSame ? $0.id < $1.id : numberOrder == .orderedAscending
        }
    }
}
