import Foundation

enum MTRStationFilter {
    struct Group: Identifiable {
        let id: String
        let stations: [MTRStation]
    }

    static func groups(stations: [MTRStation], patterns: [MTRStationPattern], query: String) -> [Group] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return [Group(id: "search", stations: stations.filter { station in
                [station.english, station.traditional, station.simplified, station.id]
                    .contains { $0.localizedStandardContains(query) }
            })]
        }
        guard !patterns.isEmpty else { return [Group(id: "all", stations: stations)] }
        // Use one published direction; do not mix the reverse pattern into the
        // list or imply that one branch terminus follows another on a train.
        let ordered = patterns.sorted {
            let lhsUp = $0.id.hasSuffix("UT"), rhsUp = $1.id.hasSuffix("UT")
            if lhsUp != rhsUp { return lhsUp }
            if $0.stations.count != $1.stations.count { return $0.stations.count > $1.stations.count }
            return $0.id < $1.id
        }
        let allowed = Set(stations.map(\.id))
        var seen = Set<String>()
        let main = ordered[0].stations.filter { allowed.contains($0.id) && seen.insert($0.id).inserted }
        let branches = ordered.dropFirst().flatMap(\.stations)
            .filter { allowed.contains($0.id) && seen.insert($0.id).inserted }
        var groups = [Group(id: "main", stations: main)]
        if !branches.isEmpty { groups.append(Group(id: "branches", stations: branches)) }
        return groups
    }
}
