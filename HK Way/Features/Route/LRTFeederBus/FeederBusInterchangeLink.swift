import SwiftUI

/// A sibling of the bus-stop link, never an interactive control inside its label.
struct FeederBusInterchangeLink: View {
    let stopID: String

    var body: some View {
        if let code = FeederBusInterchange.tuenMaStationByStopID[stopID] {
            TuenMaInterchangeLink(stationCode: code)
        }
    }
}

/// Shared by feeder buses and Light Rail; keep separate from their stop links.
struct TuenMaInterchangeLink: View {
    let stationCode: String

    // The bundled catalogue is small and immutable; parse once, not per stop row.
    private static let stations = (try? MTRStationSearchIndex.load(lineIDs: ["TML"])) ?? []

    var body: some View {
        if let line = MTRLine.all.first(where: { $0.id == "TML" }) {
            if let entry = Self.stations.first(where: { $0.id == stationCode }),
               let pattern = entry.initialPattern(lineID: line.id),
               let patterns = entry.patternsByLine[line.id] {
                NavigationLink {
                    MTRStationETAView(line: line, station: entry.station,
                                      patterns: patterns, patternID: pattern.id)
                } label: {
                    HStack(spacing: 4) {
                        MTRInterchangeBadge(line: line)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            } else {
                // Keep the informational badge if the bundled catalogue is unavailable.
                MTRInterchangeBadge(line: line)
            }
        }
    }
}
