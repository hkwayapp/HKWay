import SwiftUI

struct MTRStationSearchView: View {
    @State private var query = ""
    @State private var entries: [MTRStationSearchEntry] = []
    @State private var loaded = false
    @State private var failed = false
    private var results: [MTRStationSearchEntry] { entries.filter { $0.matches(query) } }

    var body: some View {
        Group {
            if failed {
                ContentUnavailableView("Unable to Load MTR Stations", systemImage: "tram.fill")
            } else if !loaded {
                ProgressView("Loading MTR Stations…")
            } else {
                List(results) { entry in
                    NavigationLink {
                        MTRStationLineSelectionView(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            MTRSearchStationName(station: entry.station)
                            ForEach(MTRLine.all.filter { entry.patternsByLine[$0.id] != nil }) { line in
                                MTRInterchangeBadge(line: line)
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .overlay {
                    if results.isEmpty {
                        ContentUnavailableView("No Matching MTR Stations", systemImage: "magnifyingglass")
                    }
                }
            }
        }
        .foregroundStyle(.primary)
        .navigationTitle("Find an MTR Station")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search MTR Stations")
        .task {
            guard !loaded else { return }
            do {
                entries = try MTRStationSearchIndex.load(lineIDs: MTRLine.all.map(\.id))
            } catch { failed = true }
            loaded = true
        }
    }
}

struct MTRStationQuickOpenView: View {
    let stationEnglish: String
    @State private var entry: MTRStationSearchEntry?
    @State private var failed = false

    var body: some View {
        Group {
            if let entry {
                MTRStationLineSelectionView(entry: entry)
            } else if failed {
                ContentUnavailableView("Station Unavailable", systemImage: "tram.fill")
            } else {
                ProgressView("Opening MTR Station…")
            }
        }
        .task {
            guard entry == nil, !failed else { return }
            do {
                entry = try MTRStationSearchIndex.load(lineIDs: MTRLine.all.map(\.id))
                    .first { item in
                        item.station.english.caseInsensitiveCompare(stationEnglish) == .orderedSame
                    }
                failed = entry == nil
            } catch {
                failed = true
            }
        }
    }
}

private struct MTRStationLineSelectionView: View {
    let entry: MTRStationSearchEntry
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MTRSearchStationName(station: entry.station)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .customInfoCardSurface(cornerRadius: 22)
                Text("Choose a Line for Arrivals").font(.headline)
                ForEach(MTRLine.all.filter { entry.patternsByLine[$0.id] != nil }) { line in
                    if let pattern = entry.initialPattern(lineID: line.id),
                       let patterns = entry.patternsByLine[line.id] {
                        NavigationLink {
                            MTRStationETAView(line: line, station: entry.station,
                                              patterns: patterns, patternID: pattern.id)
                        } label: {
                            HStack {
                                MTRInterchangeBadge(line: line)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(16).frame(maxWidth: .infinity, minHeight: 56)
                            .contentShape(Rectangle())
                            .customInfoCardSurface(cornerRadius: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }.padding(16)
        }
        .foregroundStyle(.primary)
        .navigationTitle("Choose MTR Line")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MTRSearchStationName: View {
    let station: MTRStation
    @Environment(\.transitLanguage) private var language
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(language == .english ? station.english :
                 language == .traditionalChinese ? station.traditional : station.simplified)
                .font(.headline)
            if language != .english {
                Text(station.english).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
