import Foundation

enum MTRStationShortcuts {
    static let recentStorageKey = "recentMTRJourneyStations.v1"
    static let recentLimit = 10

    static func recentIDs(_ value: String) -> [String] {
        var seen = Set<String>()
        return value.split(separator: "\n").map(String.init).filter {
            $0.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil && seen.insert($0).inserted
        }
    }

    static func recording(_ stationID: String, in value: String) -> String {
        guard stationID.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil else { return value }
        return ([stationID] + recentIDs(value).filter { $0 != stationID })
            .prefix(recentLimit).joined(separator: "\n")
    }

    static func resolve(_ ids: [String], stations: [MTRStation]) -> [MTRStation] {
        var seen = Set<String>()
        return ids.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return stations.first { $0.id == id }
        }
    }

    static func favorites(_ value: String, stations: [MTRStation]) -> [MTRStation] {
        // The selector chooses a station, not a saved line or direction.
        resolve(MTRFavorite.decode(value).map(\.stationID), stations: stations)
    }
}
