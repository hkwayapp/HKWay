import SwiftUI

private let kaiTakAccent = Color.red

struct KaiTakEventRoutesView: View {
    @Environment(\.transitLanguage) private var language
    @State private var venue: KaiTakVenue = .stadium

    // Add an arrangement only after an official event-specific notice confirms
    // its dates, routes, service phase and exact boarding area.
    private let verifiedArrangements: [KaiTakEventArrangement] = []

    private var visibleArrangements: [KaiTakEventArrangement] {
        KaiTakEventArrangement.current(from: verifiedArrangements)
            .filter { $0.venue == venue }
    }

    var body: some View {
        List {
            Section("Venue") {
                Picker("Venue", selection: $venue) {
                    ForEach(KaiTakVenue.allCases) { venue in
                        Text(venue.title).tag(venue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Text("Event transport arrangements change for each event. Only current services confirmed by an official event-specific notice appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if visibleArrangements.isEmpty {
                Section("Upcoming Event Arrangements") {
                    ContentUnavailableView(
                        "No Verified Upcoming Arrangements",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No current official event-specific transport notice has been verified. Check the official event and Transport Department pages before travelling.")
                    )
                }
            } else {
                ForEach(visibleArrangements) { arrangement in
                    arrangementSection(arrangement)
                }
            }

            if venue == .stadium {
                Section {
                    Text("These route identities and general destinations come from operator publications. They are not confirmed to operate for the next event.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(KaiTakSpecialRoute.catalogue) { route in
                        specialRouteCard(route)
                    }
                } header: {
                    Text("Kai Tak Special Routes Catalogue")
                } footer: {
                    Text("Opening an operator notice does not mean its old service dates are still valid. Wait for a current event notice before relying on any SP route.")
                }
            }

            Section("Official Information") {
                Link(destination: URL(string: "https://www.kaitaksportspark.com.hk/events-tickets")!) {
                    Label("Kai Tak Sports Park Events", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://www.kaitaksportspark.com.hk/getting-here")!) {
                    Label("Kai Tak Sports Park — Getting Here", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://www.td.gov.hk/en/special_news/spnews.htm")!) {
                    Label("Transport Department Special Traffic News", systemImage: "arrow.up.right.square")
                }
            }

            Section {
                Text("External websites are independent. HK Way does not provide live event-route availability; follow on-site signs and the latest official notice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(kaiTakAccent.opacity(0.09).ignoresSafeArea())
        .navigationTitle("Kai Tak Event Routes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func specialRouteCard(_ route: KaiTakSpecialRoute) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(route.number)
                    .font(.title3.bold())
                    .foregroundStyle(kaiTakAccent)
                Text(route.destination(for: language))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(route.routeOperator.displayName(for: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                CustomBadgeView(
                    text: language.localized("Event-day Only"),
                    backgroundColor: kaiTakAccent,
                    isCompact: true
                )
                Text("No confirmed service")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func arrangementSection(_ arrangement: KaiTakEventArrangement) -> some View {
        Section {
            Text(arrangement.title).font(.headline)
            CustomBadgeView(
                text: language.localized("Event-day Only"),
                backgroundColor: kaiTakAccent,
                isCompact: true
            )

            phaseView("Arrival Services", phase: .arrival, arrangement: arrangement)
            phaseView("Post-event Departure Services", phase: .departure, arrangement: arrangement)

            Link(destination: arrangement.sourceURL) {
                Label("Official Event Transport Notice", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text(arrangement.startDate.formatted(date: .abbreviated, time: .omitted))
        }
    }

    @ViewBuilder
    private func phaseView(
        _ title: LocalizedStringKey,
        phase: KaiTakServicePhase,
        arrangement: KaiTakEventArrangement
    ) -> some View {
        let services = arrangement.services.filter { $0.phase == phase }
        if !services.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.subheadline.weight(.semibold))
                ForEach(services) { service in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.route).font(.headline)
                        Text(service.operatorName).font(.subheadline)
                        Label(service.boardingArea, systemImage: "mappin.and.ellipse")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
