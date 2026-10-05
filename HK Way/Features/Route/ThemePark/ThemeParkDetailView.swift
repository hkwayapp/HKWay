import SwiftUI

extension ThemeParkDestination {
    var accent: Color {
        switch self {
        case .disneyland: Color(red: 0.55, green: 0.27, blue: 0.65)
        case .oceanPark: Color(red: 0.04, green: 0.47, blue: 0.61)
        case .waterWorld: Color(red: 0.00, green: 0.55, blue: 0.78)
        case .wetlandPark: Color(red: 0.20, green: 0.48, blue: 0.24)
        }
    }

    var stationID: String? {
        switch self {
        case .disneyland: "DIS"
        case .oceanPark: "OCP"
        case .waterWorld, .wetlandPark: nil
        }
    }

    var plannerSubtitle: LocalizedStringKey {
        switch self {
        case .disneyland: "Choose your starting station · Destination: Disneyland Resort"
        case .oceanPark: "Choose your starting station · Destination: Hong Kong Ocean Park"
        case .waterWorld, .wetlandPark: ""
        }
    }

    var officialWebsite: URL {
        switch self {
        case .disneyland: URL(string: "https://www.hongkongdisneyland.com/")!
        case .oceanPark: URL(string: "https://www.oceanpark.com.hk/en")!
        case .waterWorld: URL(string: "https://waterworld.oceanpark.com.hk/en/")!
        case .wetlandPark: URL(string: "https://www.wetlandpark.gov.hk/en/")!
        }
    }
}

struct ThemeParkDetailView: View {
    let destination: ThemeParkDestination
    @Environment(\.transitLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CustomInfoCardView(title: "") {
                    HStack(spacing: 14) {
                        Image(systemName: destination.systemImage)
                            .font(.title2).foregroundStyle(destination.accent)
                            .accessibilityHidden(true)
                        Text(LocalizedStringKey(destination.titleKey))
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(6)
                }

                Text("How to Get There").font(.headline).foregroundStyle(.secondary)
                CustomInfoCardView(title: "") {
                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink {
                            ThemeParkRouteListView(destination: destination)
                        } label: {
                            navigationRow("Bus Routes", subtitle: "Direct and pass-by routes",
                                          icon: "bus.fill")
                        }
                        .buttonStyle(.plain)
                        Text("Routes shown may travel directly to the theme park or serve it as an intermediate stop.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let stationID = destination.stationID {
                            Divider()
                            NavigationLink {
                                MTRJourneyPlannerView(destinationStationID: stationID)
                            } label: {
                                navigationRow("MTR Journey Planner", subtitle: destination.plannerSubtitle,
                                              icon: "tram.fill")
                            }
                            .buttonStyle(.plain)
                            Text("The planner covers the MTR journey to the selected station only. Park admission and travel from the station to the entrance are not included.")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else if destination == .wetlandPark {
                            Divider()
                            NavigationLink {
                                LightRailStopETAView(
                                    stop: LightRailStop(
                                        stationID: 530,
                                        english: "Wetland Park",
                                        traditional: "濕地公園",
                                        simplified: "湿地公园"
                                    ),
                                    servedRouteIDs: ["705", "706"]
                                )
                            } label: {
                                navigationRow("Light Rail Arrivals",
                                              subtitle: "Routes 705 and 706 · Wetland Park Stop",
                                              icon: "tram.fill")
                            }
                            .buttonStyle(.plain)
                            Text("From Tin Shui Wai Station, the official visitor information recommends changing to Light Rail route 705 and alighting at Wetland Park Stop or Tin Sau Stop.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(6)
                }

                Text("Visitor Information").font(.headline).foregroundStyle(.secondary)
                CustomInfoCardView(title: "") {
                    VStack(alignment: .leading, spacing: 12) {
                        Link(destination: destination.officialWebsite) {
                            HStack(spacing: 12) {
                                Image(systemName: "safari").foregroundStyle(destination.accent)
                                    .accessibilityHidden(true)
                                Text("Official Park Website").font(.headline)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Text("Check the park's official website for opening hours, tickets, reservations, accessibility and service notices. Visitor details and live park status are not reproduced here.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(6)
                }
                Text("External links open third-party websites. HK Way is independent and is not affiliated with the attraction or transport operators.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(destination.accent.opacity(0.10).ignoresSafeArea())
        .navigationTitle(destination.title(for: language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func navigationRow(_ title: LocalizedStringKey, subtitle: LocalizedStringKey,
                               icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(destination.accent)
                .frame(width: 26).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
    }
}
