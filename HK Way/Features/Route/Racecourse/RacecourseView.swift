import SwiftData
import SwiftUI

private enum RacecoursePlace: String, CaseIterable, Identifiable {
    case shaTin, happyValley

    var id: String { rawValue }
    var title: LocalizedStringKey {
        self == .shaTin ? "Sha Tin Racecourse" : "Happy Valley Racecourse"
    }

    // Exact IDs from the existing open transport dataset, not fuzzy area-name matches.
    var stopIDs: [String] {
        switch self {
        case .shaTin: ["gmb-20010665"]
        case .happyValley:
            ["69", "365", "8055", "gmb-20006937", "gmb-20011592", "gmb-20012606"]
        }
    }

    var officialURL: URL {
        URL(string: self == .shaTin
            ? "https://entertainment.hkjc.com/en-us/visit-us/sha-tin-racecourse"
            : "https://happywednesday.hkjc.com/en-US/plan-your-visit/")!
    }
}

private let racecourseAccent = Color(red: 0.10, green: 0.42, blue: 0.28)
private let racecourseEastRailLine = MTRLine.all.first { $0.id == "EAL" }!
private let racecourseMTRStation = MTRStation(
    id: "RAC",
    traditional: "馬場",
    english: "Racecourse"
)
private let racecourseEastRailPatterns =
    (try? MTRStations.load(line: "EAL")) ?? []

struct RacecourseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose a Racecourse").font(.headline).foregroundStyle(.secondary)
                ForEach(RacecoursePlace.allCases) { place in
                    NavigationLink {
                        RacecourseConnectionsView(place: place)
                    } label: {
                        CustomInfoCardView(title: "") {
                            HStack(spacing: 14) {
                                Image(systemName: "flag.checkered")
                                    .foregroundStyle(racecourseAccent).accessibilityHidden(true)
                                Text(place.title).font(.title3.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption)
                                    .foregroundStyle(.secondary).accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text("Browse dataset connections separately from race-day arrangements. A listed route does not mean it is running now.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(racecourseAccent.opacity(0.10).ignoresSafeArea())
        .navigationTitle("Racecourse Routes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RacecourseConnectionsView: View {
    let place: RacecoursePlace
    @Environment(\.transitLanguage) private var transitLanguage
    @Query private var stopVisits: [JourneyStopEntity]
    @State private var routes: [RouteEntity] = []
    @State private var isLoading = true

    init(place: RacecoursePlace) {
        self.place = place
        let ids = place.stopIDs
        let predicate = #Predicate<JourneyStopEntity> { visit in
            visit.stop.flatMap { stop in ids.contains(stop.id) } ?? false
        }
        _stopVisits = Query(filter: predicate)
    }

    var body: some View {
        List {
            if place == .shaTin {
                Section {
                    racecourseRailCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    happyValleyTramCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            Section {
                Text("Selected routes serving named racecourse-area stops in the open dataset. Check the direction, stop location and operating days before travelling; this is not an entrance or walking guide.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if place == .shaTin {
                    Text("The listed minibus connection serves the Sha Tin Racecourse (Penfold Park) stop. Route 60R is a supplementary service; do not assume daily or race-day operation.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Racecourse-area Connections") {
                if isLoading {
                    ProgressView("Loading connecting routes…")
                        .frame(maxWidth: .infinity, minHeight: 70)
                } else if routes.isEmpty {
                    ContentUnavailableView("No Connecting Routes", systemImage: "bus.fill",
                                           description: Text("Update the dataset and try again."))
                } else {
                    ForEach(routes) { route in
                        NavigationLink {
                            RouteDetailView(route: route)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                RouteRowView(route: route, etaResult: nil, isCompact: true,
                                             allowsTwoLineOrigin: true, allowsTwoLineDestination: true,
                                             allowsFullNameWrapping: true, usesUniformNameStyle: true)

                                if place == .shaTin,
                                   route.number.caseInsensitiveCompare("60R") == .orderedSame {
                                    CustomBadgeView(
                                        text: transitLanguage.localized("Supplementary Service"),
                                        backgroundColor: racecourseAccent,
                                        isCompact: true
                                    )
                                    .accessibilityLabel("Supplementary Service")
                                }
                            }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            Section("Race-day Services") {
                Text("Dedicated race-day route lists and live event availability are not provided here. Check the official arrangements for your visit, including boarding points and return services.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Link(destination: place.officialURL) {
                    Label("Official Racecourse Transport Information", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .foregroundStyle(.primary)
            }
            Section {
                Text("Route data comes from DATA.GOV.HK and the app's open transport dataset. Data rights remain with their respective owners. External websites are independent; HK Way is not affiliated with HKJC or the transport operators.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(racecourseAccent.opacity(0.10).ignoresSafeArea())
        .navigationTitle(place.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: stopVisits.map { "\($0.id):\($0.journey?.route?.id ?? "")" }.sorted()) {
            isLoading = true
            await Task.yield()
            guard !Task.isCancelled else { return }
            var seen = Set<String>()
            routes = stopVisits.compactMap { $0.journey?.route }
                .filter { seen.insert($0.id).inserted }
                .sorted {
                    let order = $0.number.localizedStandardCompare($1.number)
                    return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
                }
            isLoading = false
        }
    }

    private var racecourseRailCard: some View {
        CustomInfoCardView(title: "") {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("East Rail Line · Racecourse Station")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "tram.fill")
                        .foregroundStyle(racecourseEastRailLine.color)
                        .accessibilityHidden(true)
                }
                Text("Race-day service — check official arrangements")
                    .font(.subheadline.weight(.semibold))
                Text("Racecourse station is not a daily connection. Check MTR's latest arrangements and station announcements before travelling. Live arrivals appear only when MTR reports a service at this station.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                NavigationLink {
                    MTRStationETAView(
                        line: racecourseEastRailLine,
                        station: racecourseMTRStation,
                        patterns: racecourseEastRailPatterns,
                        patternID: "EAL-DT"
                    )
                } label: {
                    Label("View Racecourse Station Arrivals", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
                Link(destination: URL(string: "https://www.mtr.com.hk/en/customer/services/service_hours_search.php?query_type=search&station=70")!) {
                    Label("MTR — Racecourse Station Information", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .foregroundStyle(.primary)
        }
    }

    private var happyValleyTramCard: some View {
        CustomInfoCardView(title: "") {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Hong Kong Tramways · Happy Valley Terminus")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "tram.fill")
                        .foregroundStyle(Color.green)
                        .accessibilityHidden(true)
                }

                Text("Regular tram connection — check the selected route and direction before travelling.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                NavigationLink {
                    TramView(requiredEnglishStopName: "Happy Valley")
                } label: {
                    Label("Browse Tram Routes", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .foregroundStyle(.primary)
        }
    }
}
