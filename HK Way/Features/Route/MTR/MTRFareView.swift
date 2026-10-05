import SwiftUI

struct MTRFareView: View {
    let boardingStation: MTRStation
    let airportExpress: Bool
    @Environment(\.transitLanguage) private var language
    @State private var stations: [MTRFareStation] = []
    @State private var fares: [String: MTRAdultFare] = [:]
    @State private var selectedCode: String?
    @State private var loaded = false
    @State private var failed = false
    @State private var showingDestinations = false

    private var origin: MTRFareStation? { stations.first { $0.id == boardingStation.id } }
    private var destinations: [MTRFareStation] {
        guard let origin else { return [] }
        return MTRFares.destinations(from: origin, stations: stations, fares: fares)
    }
    private var selected: MTRFareStation? { destinations.first { $0.id == selectedCode } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adult Fares").font(.headline)
            if !loaded {
                ProgressView("Loading Fares…")
            } else if failed || origin == nil {
                Text("Unable to Load MTR Fares").foregroundStyle(.secondary)
            } else if destinations.isEmpty {
                Text("Fare unavailable for this journey.").foregroundStyle(.secondary)
            } else {
                Button { showingDestinations = true } label: {
                    HStack(spacing: 10) {
                        Text("To").font(.headline)
                        if let selected {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name(selected.station))
                                if language != .english {
                                    Text(selected.station.english).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("Choose Fare Destination")
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(16).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .customInfoCardSurface(cornerRadius: 18)
                }
                .buttonStyle(.plain)
                if let origin, let selected,
                   let fare = fares[MTRFares.key(from: origin.fareID, to: selected.fareID)] {
                    HStack(spacing: 12) {
                        CustomInfoCardView(title: "Adult Octopus") {
                            Text(price(fare.octopus)).font(.title2.bold()).minimumScaleFactor(0.75).lineLimit(1)
                        }
                        CustomInfoCardView(title: "Adult Single Journey") {
                            Text(price(fare.singleJourney)).font(.title2.bold()).minimumScaleFactor(0.75).lineLimit(1)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(airportExpress
                    ? "Airport Express fares only. No combined railway fare or promotional discount is calculated."
                    : "Standard adult railway fares, excluding Airport Express, First Class and concessions. Transfers may be required."))
                Text("Fare selection does not change the ETA direction or guarantee a direct train.")
                Text("Fare data retrieved: 2026-08-31. Prices may change.")
                Text("Fare data: MTR Corporation Limited via DATA.GOV.HK; data intellectual property belongs to MTR Corporation Limited.")
                Link("Official MTR Fare Data", destination: URL(string: "https://data.gov.hk/en-data/dataset/mtr-data-routes-fares-barrier-free-facilities")!)
                    .foregroundStyle(.primary)
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .sheet(isPresented: $showingDestinations) {
            MTRFareDestinationPicker(stations: destinations, selectedCode: $selectedCode)
                .environment(\.transitLanguage, language)
                .environment(\.locale, language.locale)
        }
        .task(id: "\(boardingStation.id)|\(airportExpress)") {
            loaded = false
            failed = false
            selectedCode = nil
            do {
                stations = try MTRStations.loadFareStations(airportExpress: airportExpress)
                fares = try MTRFares.load(airportExpress: airportExpress)
            } catch { failed = true }
            loaded = true
        }
    }

    private func name(_ station: MTRStation) -> String {
        switch language {
        case .english: station.english
        case .traditionalChinese: station.traditional
        case .simplifiedChinese: station.simplified
        }
    }
    private func price(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_HK")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return "HK$" + (f.string(from: NSDecimalNumber(decimal: value)) ?? "—")
    }
}

private struct MTRFareDestinationPicker: View {
    let stations: [MTRFareStation]
    @Binding var selectedCode: String?
    @Environment(\.transitLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var filtered: [MTRFareStation] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return stations.filter {
            search.isEmpty || [$0.station.english, $0.station.traditional, $0.station.simplified]
                .contains { $0.localizedStandardContains(search) }
        }
    }
    var body: some View {
        NavigationStack {
            List(filtered) { entry in
                Button {
                    selectedCode = entry.id
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language == .english ? entry.station.english :
                                 language == .traditionalChinese ? entry.station.traditional : entry.station.simplified)
                            if language != .english {
                                Text(entry.station.english).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if entry.id == selectedCode { Image(systemName: "checkmark") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.primary)
            .searchable(text: $query, prompt: "Search MTR Stations")
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView("No Matching MTR Stations", systemImage: "magnifyingglass")
                }
            }
            .navigationTitle("Choose Fare Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(.primary)
                }
            }
        }
    }
}
