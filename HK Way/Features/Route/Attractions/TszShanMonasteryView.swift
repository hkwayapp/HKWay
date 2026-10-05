import SwiftUI

struct TszShanMonasteryView: View {
    private let accent = Color(red: 0.52, green: 0.36, blue: 0.20)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                card("Tsz Shan Monastery", icon: "building.columns.fill") {
                    Text("Plan your transport below. Registration and current visitor information are available from the monastery's official website.")
                        .font(.subheadline)
                }

                card("How to Get There", icon: "signpost.right.fill") {
                    NavigationLink {
                        TszShanMonasteryBusRoutesView()
                    } label: {
                        actionRow(
                            "Browse Supported Bus Routes",
                            subtitle: "Direct and nearby connections",
                            icon: "bus.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    Divider()
                    routeGroup(
                        title: "Direct limited service",
                        routes: "Green Minibus 20T",
                        detail: "Serves the monastery entrance on Mondays to Fridays, except public holidays. Check the official page for current departure times before travelling.",
                        badge: "Limited service"
                    )
                    Divider()
                    routeGroup(
                        title: "Nearby services",
                        routes: "Green Minibus 20B, 20C · Bus 75K, 275R · Resident Service NR532",
                        detail: "These services use nearby boarding points and require an onward walk. Route 275R is a Sunday and public-holiday service. Check the official directions before travelling."
                    )
                    Divider()
                    externalLink(
                        "Official Getting Here Information",
                        url: "https://www.tszshan.org/home/new/en/visit.php#transaction",
                        icon: "map.fill"
                    )
                    Text("HK Way does not provide live arrivals for these monastery connections on this page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                card("Visitor Information", icon: "link") {
                    Text("Use the official website for registration, visit guidelines, accessibility arrangements and current visitor notices. HK Way does not reproduce those details here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    externalLink(
                        "Official Visit Information",
                        url: "https://www.tszshan.org/home/new/en/visit.php"
                    )
                    Divider()
                    externalLink(
                        "Official Online Registration",
                        url: "https://registration.tszshan.org/?locale=en_US",
                        icon: "checkmark.circle.fill"
                    )
                    Text("External links open third-party websites. HK Way is independent and is not affiliated with the attraction or transport operators.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(accent.opacity(0.10).ignoresSafeArea())
        .navigationTitle("Tsz Shan Monastery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func routeGroup(
        title: LocalizedStringKey,
        routes: LocalizedStringKey,
        detail: LocalizedStringKey,
        badge: LocalizedStringKey? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.subheadline.bold())
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.16), in: Capsule())
                }
            }
            Text(routes)
                .font(.headline)
                .foregroundStyle(accent)
            Text(detail)
                .font(.subheadline)
        }
    }

    private func actionRow(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func externalLink(
        _ title: LocalizedStringKey,
        url: String,
        icon: String = "safari"
    ) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}
