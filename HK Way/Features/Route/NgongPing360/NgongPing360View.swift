import SwiftUI

struct NgongPing360View: View {
    private let accent = Color(red: 0.13, green: 0.58, blue: 0.78)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CustomInfoCardView(title: "Ngong Ping 360") {
                    VStack(spacing: 10) {
                        Image(systemName: "cablecar.fill")
                            .font(.largeTitle).foregroundStyle(accent)
                            .accessibilityHidden(true)
                        Text("Transport connections & official links")
                            .font(.headline).multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 8)
                }

                Text("How to Get There").font(.headline).foregroundStyle(.secondary)
                card("Tung Chung Connections", icon: "tram.fill") {
                    NavigationLink {
                        MTRJourneyPlannerView(viaTungChung: true)
                    } label: {
                        navigationRow("MTR Journey Planner",
                                      subtitle: "Choose your starting station · Destination: Tung Chung",
                                      icon: "tram.fill")
                    }
                    .buttonStyle(.plain)
                    Text("The MTR planner ends at Tung Chung station. It does not include the cable-car journey or the route from the station to the terminal.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                card("Ngong Ping Connections", icon: "bus.fill") {
                    NavigationLink {
                        BuddhaBusRoutesView()
                    } label: {
                        navigationRow("Bus Routes to Ngong Ping",
                                      subtitle: "23 from Tung Chung · 2 from Mui Wo · 21 from Tai O",
                                      icon: "bus.fill")
                    }
                    .buttonStyle(.plain)
                    Text("These are selected bus routes serving the Ngong Ping bus terminus, not the cable-car boarding point. Use the official guide for terminal access and check your return service separately.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                card("Official Information", icon: "link") {
                    officialLink("NP360 Official Website & Service Notices", url: "https://www.np360.com.hk/en", icon: "safari")
                    Divider()
                    officialLink("NP360 Official Ticket Store", url: "https://webstore.np360.com.hk/EN", icon: "ticket")
                    Divider()
                    officialLink("NP360 Visitor Guide & Accessibility", url: "https://www.np360.com.hk/en/visitor-information/tourist-guide", icon: "accessibility")
                    Text("Check NP360's official website for operating hours, prices, cabin options, accessibility and any service changes. No cable-car ETA or live operating status is provided in HK Way.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Text("External links open third-party websites. HK Way is independent and is not affiliated with the attraction or transport operators.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(accent.opacity(0.10).ignoresSafeArea())
        .navigationTitle("Ngong Ping 360")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card<Content: View>(_ title: LocalizedStringKey, icon: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func navigationRow(_ title: LocalizedStringKey, subtitle: LocalizedStringKey,
                               icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func officialLink(_ title: LocalizedStringKey, url: String, icon: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(accent).frame(width: 28)
                Text(title).font(.subheadline)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}
