import SwiftUI

private extension FerryOperator {
    // App-authored colour accents, not operator logos.
    var color: Color {
        switch self {
        case .star: Color(red: 0.10, green: 0.43, blue: 0.30)
        case .sun: .orange
        case .hkkf: Color(red: 0.18, green: 0.36, blue: 0.65)
        case .parkIsland: .teal
        }
    }
}

private enum FerryBrowseMode: String, CaseIterable, Identifiable {
    case pier = "By Pier", location = "By Location", operatorName = "By Operator"
    var id: String { rawValue }
}

struct FerryView: View {
    @State private var mode: FerryBrowseMode = .pier
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if typeSize.isAccessibilitySize {
                    browsePicker.pickerStyle(.menu)
                } else {
                    browsePicker.pickerStyle(.segmented)
                }
                Text("Starter ferry routes only. Choose a pier, location or operator; live departures are not included.")
                    .font(.footnote).foregroundStyle(.secondary)
                if mode == .pier {
                    ForEach(FerryPierRegion.allCases) { region in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey(region.rawValue))
                                .font(.headline).foregroundStyle(.secondary)
                                .accessibilityAddTraits(.isHeader)
                            CustomInfoCardView(title: "") {
                                VStack(spacing: 0) {
                                    ForEach(region.piers) { pier in
                                        browseRow(pier.title, routes: FerryCatalogue.routes(at: pier), icon: "mappin.and.ellipse", departurePier: pier)
                                        if pier != region.piers.last { Divider() }
                                    }
                                }
                            }
                        }
                    }
                } else if mode == .location {
                    ForEach(FerryPierRegion.allCases) { region in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey(region.rawValue))
                                .font(.headline).foregroundStyle(.secondary)
                                .accessibilityAddTraits(.isHeader)
                            CustomInfoCardView(title: "") {
                                VStack(spacing: 0) {
                                    ForEach(region.locations) { location in
                                        browseRow(location.title, routes: FerryCatalogue.routes(in: location),
                                                  icon: "location", departureLocation: location)
                                        if location != region.locations.last { Divider() }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    CustomInfoCardView(title: "") {
                        VStack(spacing: 0) {
                            ForEach(FerryOperator.allCases) { operatorID in
                                browseRow(operatorID.title, routes: FerryCatalogue.routes(by: operatorID),
                                          icon: "ferry.fill", color: operatorID.color)
                                if operatorID != FerryOperator.allCases.last { Divider() }
                            }
                        }
                    }
                }
                FerrySourceNote()
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(Color.cyan.opacity(0.10).ignoresSafeArea())
        .navigationTitle("Ferry")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var browsePicker: some View {
        Picker("Browse Ferries", selection: $mode) {
            ForEach(FerryBrowseMode.allCases) { option in
                Text(LocalizedStringKey(option.rawValue)).tag(option)
            }
        }
    }

    private func browseRow(_ title: String, routes: [FerryConnection], icon: String,
                           color: Color = .primary, departurePier: FerryPier? = nil,
                           departureLocation: FerryLocation? = nil) -> some View {
        NavigationLink {
            FerryRouteListView(title: title, routes: routes, departurePier: departurePier,
                               departureLocation: departureLocation)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(color).frame(width: 26).accessibilityHidden(true)
                FerryName(title: title)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FerryName: View {
    let title: String
    var body: some View {
        Text(LocalizedStringKey(title))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FerryRouteListView: View {
    let title: String
    let routes: [FerryConnection]
    let departurePier: FerryPier?
    let departureLocation: FerryLocation?

    var body: some View {
        List {
            Section {
                ForEach(routes) { route in
                    let departure = route.initialDeparture(pier: departurePier, location: departureLocation)
                    NavigationLink {
                        FerryConnectionView(route: route, departure: departure)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            FerryOperatorLabel(operatorID: route.operatorID)
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "arrow.down")
                                    .foregroundStyle(route.operatorID.color).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    FerryName(title: departure.title)
                                    FerryName(title: route.arrival(from: departure).title)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Ferry Connections")
            } footer: {
                Text("Open a route to change direction. Check the official timetable for your departure pier and travel date.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.cyan.opacity(0.10).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey(title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FerryOperatorLabel: View {
    let operatorID: FerryOperator
    var body: some View {
        if operatorID == .parkIsland {
            Text(LocalizedStringKey(operatorID.title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(operatorID.color, in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: 6) {
                Circle().fill(operatorID.color).frame(width: 9, height: 9).accessibilityHidden(true)
                Text(LocalizedStringKey(operatorID.title)).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
    }
}

struct FerryConnectionView: View {
    let route: FerryConnection
    @State private var departure: FerryPier
    @State private var fastService = true
    @Environment(\.transitLanguage) private var language
    @Environment(\.dynamicTypeSize) private var typeSize

    init(route: FerryConnection, departure: FerryPier) {
        self.route = route
        _departure = State(initialValue: route.initialDeparture(pier: departure))
    }

    private var officialURL: URL {
        route.officialURL(languagePath: language == .english ? "en" : language == .traditionalChinese ? "tc" : "sc")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Departure Pier").font(.headline)
                    if typeSize.isAccessibilitySize {
                        directionPicker.pickerStyle(.menu)
                    } else {
                        directionPicker.pickerStyle(.segmented)
                    }
                }
                CustomInfoCardView(title: "") {
                    VStack(alignment: .leading, spacing: 12) {
                        FerryOperatorLabel(operatorID: route.operatorID)
                        Text("Departure Pier").font(.caption).foregroundStyle(.secondary)
                        FerryName(title: departure.title).font(.title3.weight(.semibold))
                        Image(systemName: "arrow.down").foregroundStyle(route.operatorID.color)
                            .accessibilityHidden(true)
                        Text("Arrival Pier").font(.caption).foregroundStyle(.secondary)
                        FerryName(title: route.arrival(from: departure).title).font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                if ["7005", "7006"].contains(route.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ferry Service Type").font(.headline)
                        if typeSize.isAccessibilitySize {
                            servicePicker.pickerStyle(.menu)
                        } else {
                            servicePicker.pickerStyle(.segmented)
                        }
                        Text("Service types share the same piers. This selection shows reference journey times only; check the official timetable for fast-ferry departures and applicable fares.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    CustomInfoCardView(title: "Journey Duration") {
                        if route.id == "7005" {
                            Text(fastService ? LocalizedStringKey("About 35–40 min") : LocalizedStringKey("About 55–60 min"))
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if route.id == "7006", fastService {
                            Text(LocalizedStringKey("About 35–40 min"))
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let minutes = route.referenceMinutes {
                            Text("About \(minutes) min").font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            officialValueLink
                        }
                    }
                    CustomInfoCardView(title: "Ferry Fare") {
                        officialValueLink
                    }
                }
                Text("Duration is a reference, not a live arrival estimate. Fares and sailing times can vary by day, vessel and deck. Where details are not reliably represented in the dataset, use the official information.")
                    .font(.footnote).foregroundStyle(.secondary)
                if route.id == "7005" {
                    CheungChauTimetableView(departure: departure,
                                            type: fastService ? .fast : .ordinary)
                }
                if route.id == "7006" {
                    MuiWoTimetableView(departure: departure,
                                       type: fastService ? .fast : .ordinary)
                }
                if route.id == "7007" {
                    CustomInfoCardView(title: "") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ferry Service Type").font(.headline)
                            Text("The current Central–Peng Chau timetable does not identify separate fast and ordinary sailings. All published departures are shown below; check official information for vessel arrangements.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                    PengChauTimetableView(departure: departure)
                }
                if route.id == "7009" {
                    CustomInfoCardView(title: "") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ferry Service Type").font(.headline)
                            Text("The current Central–Yung Shue Wan timetable does not identify separate fast and ordinary sailings. All published departures are shown below; check official information for vessel arrangements.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                    YungShueWanTimetableView(departure: departure)
                }
                if route.id == "7008" {
                    CustomInfoCardView(title: "") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ferry Service Type").font(.headline)
                            Text("The current Central–Sok Kwu Wan timetable does not identify separate fast and ordinary sailings. All published departures are shown below; conditional additional sailings are labelled.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                    }
                    SokKwuWanTimetableView(departure: departure)
                }
                CustomInfoCardView(title: "") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Timetables & Service Information").font(.headline)
                        Link(destination: officialURL) {
                            Label("Official Ferry Timetable & Fares", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Text("Check the departure pier, return sailing and service notices before travelling. No live ferry departures or operating status are provided here.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                FerrySourceNote()
            }
            .padding(16)
        }
        .foregroundStyle(.primary)
        .background(route.operatorID.color.opacity(0.10).ignoresSafeArea())
        .navigationTitle("Ferry Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var servicePicker: some View {
        Picker("Ferry Service Type", selection: $fastService) {
            Text("Fast Ferry").font(.headline).tag(true)
            Text("Ordinary Ferry").font(.headline).tag(false)
        }
        .font(.headline)
        .controlSize(.large)
        .tint(.primary)
        .foregroundStyle(.primary)
    }

    private var directionPicker: some View {
        Picker("Departure Pier", selection: $departure) {
            ForEach(route.piers) { pier in
                Text(LocalizedStringKey(pier.location.title)).tag(pier)
            }
        }
        .foregroundStyle(.primary)
    }

    private var officialValueLink: some View {
        Link(destination: officialURL) {
            Text("See Official Details").font(.headline)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

private struct FerrySourceNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected route data: Transport Department / DATA.GOV.HK. Data rights belong to their respective owners. HK Way is independent of the operators.")
            Text("Ferry starter catalogue checked: 2026-09-01. Routes and arrangements may change; this is not a live service feed.")
            Link("Ferry Open Data Source", destination: URL(string: "https://data.gov.hk/en-data/dataset/hk-td-tis_14-routes-fares-xml/resource/8a8b06bf-c624-4f2c-b014-ea9586320a66")!)
                .foregroundStyle(.primary)
        }
        .font(.footnote).foregroundStyle(.secondary)
    }
}
