import SwiftUI

struct MTRFavoritesView: View {
    @AppStorage(MTRFavorite.storageKey) private var stored = ""
    @Environment(\.transitLanguage) private var language
    @State private var entries: [MTRStationSearchEntry] = []
    @State private var loaded = false
    @State private var failed = false
    private var favorites: [MTRFavorite] { MTRFavorite.decode(stored) }

    var body: some View {
        Group {
            if favorites.isEmpty {
                CustomCardView(
                    imageIcon: "train.side.front.car",
                    title: "No Favorite MTR Stations",
                    subTitle: "Choose a direction on an MTR station’s arrivals page, then tap the bookmark to save it.",
                    animated: false
                )
            } else if failed {
                ContentUnavailableView("Unable to Load MTR Stations", systemImage: "tram.fill")
            } else if !loaded {
                ProgressView("Loading MTR Stations…")
            } else {
                List {
                    ForEach(favorites) { favorite in
                        Group {
                            if let entry = entries.first(where: { $0.id == favorite.stationID }),
                               let line = MTRLine.all.first(where: { $0.id == favorite.lineID }),
                               let patterns = entry.patternsByLine[line.id],
                               let pattern = patterns.first(where: {
                                   MTRTravelDirection(patternID: $0.id).rawValue == favorite.direction &&
                                   $0.stations.contains { $0.id == favorite.stationID }
                               }) {
                                NavigationLink {
                                    MTRStationETAView(line: line, station: entry.station,
                                                      patterns: patterns, patternID: pattern.id)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(name(entry.station)).font(.headline)
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("To")
                                                Text(destinations(patterns, direction: favorite.direction))
                                            }
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        MTRInterchangeBadge(line: line)
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(favorite.lineID) · \(favorite.stationID)")
                                    Text("Saved MTR service unavailable. Remove this favorite and save it again from the station page.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                stored = MTRFavorite.removing(favorite, from: stored)
                            } label: { Label("Remove", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .foregroundStyle(.primary)
        .task {
            guard !loaded else { return }
            do { entries = try MTRStationSearchIndex.load(lineIDs: MTRLine.all.map(\.id)) }
            catch { failed = true }
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

    private func destinations(_ patterns: [MTRStationPattern], direction: String) -> String {
        var seen = Set<String>()
        return patterns.filter { MTRTravelDirection(patternID: $0.id).rawValue == direction }
            .compactMap { $0.stations.last }.filter { seen.insert($0.id).inserted }
            .map(name).joined(separator: " / ")
    }
}
