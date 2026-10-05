import SwiftData
import SwiftUI

struct LRTFeederBusView: View {
    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    private var feederRoutes: [RouteEntity] {
        routes.filter { route in
            route.operators.contains { $0.id == "LRTFeeder" }
        }
    }

    var body: some View {
        ZStack {
            if feederRoutes.isEmpty {
                CustomCardView(
                    imageIcon: "bus.fill",
                    title: "No LRT Feeder Bus Routes",
                    subTitle: "Update transit data and try again.",
                    animated: false
                )
                .padding()
            } else {
                List(feederRoutes) { route in
                    NavigationLink {
                        RouteDetailView(route: route)
                    } label: {
                        RouteRowView(
                            route: route,
                            etaResult: nil,
                            isCompact: true,
                            allowsTwoLineOrigin: true,
                            allowsTwoLineDestination: true,
                            usesUniformNameStyle: true
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("LRT Feeder Bus")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LRTFeederBusView()
    }
}
