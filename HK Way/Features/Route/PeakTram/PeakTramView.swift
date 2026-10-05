import SwiftUI

struct PeakTramView: View {
    private let officialServiceURL = URL(
        string: "https://www.thepeak.com.hk/en/getting-to-the-peak/transportation"
    )!
    private let officialTicketURL = URL(
        string: "https://webstore.thepeak.com.hk/"
    )!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                routeCard
                connectingRoutesCard
                serviceInformationCard
                fareCard
                accessibilityCard
                officialLinksCard

                Label(
                    "Peak Tram does not provide live arrival times. Check the official website for service notices before travelling.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding()
        }
        .navigationTitle("Peak Tram")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Stations", systemImage: "cablecar.fill")
                .font(.headline)

            stationRow(
                title: "Central Terminus",
                subtitle: "33 Garden Road, Central",
                isLast: false
            )
            stationRow(
                title: "Peak Terminus",
                subtitle: "The Peak Tower",
                isLast: true
            )

            Divider()

            Text("Intermediate stops are request stops. Confirm boarding arrangements with staff before travelling.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .customInfoCardSurface(cornerRadius: 22)
    }

    private func stationRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(.primary)
                    .frame(width: 13, height: 13)

                if !isLast {
                    Rectangle()
                        .fill(.primary.opacity(0.25))
                        .frame(width: 3, height: 38)
                }
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var serviceInformationCard: some View {
        informationCard(title: "Service Information", icon: "clock.fill") {
            informationRow(title: "Operating Hours", value: "7:30 AM–11:00 PM")
            Divider()
            informationRow(title: "Service Days", value: "Daily, including public holidays")
            Divider()
            informationRow(title: "Frequency", value: "About every 10–12 minutes")
        }
    }

    private var connectingRoutesCard: some View {
        NavigationLink {
            PeakTramConnectingRoutesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bus.fill")
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Connecting Routes")
                        .font(.headline)

                    Text("View direct and pass-by routes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .customInfoCardSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }

    private var fareCard: some View {
        informationCard(title: "Peak Tram Fares", icon: "ticket.fill") {
            fareRow(title: "Adult", single: "HK$82", returnFare: "HK$116")
            Divider()
            fareRow(title: "Child / Senior", single: "HK$52", returnFare: "HK$75")

            Text("Single and return Peak Tram tickets. Other packages and promotions may have different prices.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var accessibilityCard: some View {
        informationCard(title: "Accessibility", icon: "accessibility") {
            Text("The Central Terminus and sixth-generation trams provide improved wheelchair access. Contact staff for assistance and confirm access at intermediate stops before travelling.")
                .font(.subheadline)
        }
    }

    private var officialLinksCard: some View {
        informationCard(title: "Official Information", icon: "link") {
            Link(destination: officialServiceURL) {
                linkRow(title: "Service Information", icon: "safari")
            }
            .foregroundStyle(.primary)

            Divider()

            Link(destination: officialTicketURL) {
                linkRow(title: "Tickets and Current Prices", icon: "ticket")
            }
            .foregroundStyle(.primary)
        }
    }

    private func informationCard<Content: View>(
        title: LocalizedStringKey,
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

    private func informationRow(
        title: LocalizedStringKey,
        value: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func fareRow(
        title: LocalizedStringKey,
        single: String,
        returnFare: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            HStack {
                Text("Single")
                    .foregroundStyle(.secondary)
                Text(verbatim: single)
                Spacer()
                Text("Return")
                    .foregroundStyle(.secondary)
                Text(verbatim: returnFare)
            }
            .font(.subheadline)
        }
    }

    private func linkRow(
        title: LocalizedStringKey,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
    }
}

#Preview {
    NavigationStack {
        PeakTramView()
    }
}
