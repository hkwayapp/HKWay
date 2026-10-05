import SwiftUI
import SwiftData

enum AirportServiceArea: String, CaseIterable, Identifiable {
    case hki
    case kln
    case nt

    var id: Self { self }

    var displayCode: String {
        rawValue.uppercased()
    }

    func title(for language: TransitLanguage) -> String {
        switch self {
        case .hki: language.localized("Hong Kong Island")
        case .kln: language.localized("Kowloon")
        case .nt: language.localized("New Territories")
        }
    }
}

struct AirportRouteAreaView: View {
    let category: AirportRouteCategory

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Query(sort: \RouteEntity.number)
    private var routes: [RouteEntity]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var availableAreas: [AirportServiceArea] {
        AirportServiceArea.allCases.filter { area in
            matchingRoutes.contains { route in
                AirportRouteGeography.serviceAreas(for: route)
                    .contains(area)
            }
        }
    }

    private var matchingRoutes: [RouteEntity] {
        routes.filter {
            category.matches(routeNumber: $0.number)
                && AirportRouteGeography.servesAirport($0)
        }
    }

    var body: some View {
        ZStack {
            CustomAppBackgroundView()

            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Please Select District")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    NavigationLink {
                        AirportRouteListView(
                            category: category,
                            area: nil
                        )
                    } label: {
                        areaCard(
                            message: allRoutesTitle
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(availableAreas) { area in
                        NavigationLink {
                            AirportRouteListView(
                                category: category,
                                area: area
                            )
                        } label: {
                            areaCard(
                                message: area.title(for: transitLanguage)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            }
        }
        .navigationTitle(
            category.navigationTitle(
                for: transitLanguage
            )
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func areaCard(
        message: String
    ) -> some View {
        CustomInfoCardView(title: departureAreaTitle) {
            Text(verbatim: message)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
        }
    }

    private var allRoutesTitle: String {
        transitLanguage.localized("All Routes")
    }

    private var departureAreaTitle: String {
        transitLanguage.localized("Departing From")
    }
}

#Preview {
    NavigationStack {
        AirportRouteAreaView(category: .a)
    }
    .modelContainer(
        for: [
            RouteEntity.self,
            JourneyEntity.self,
            JourneyStopEntity.self,
            StopEntity.self,
            OperatorEntity.self
        ],
        inMemory: true
    )
}
