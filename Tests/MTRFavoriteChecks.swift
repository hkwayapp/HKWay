import Foundation

@main enum MTRFavoriteChecks {
    static func main() throws {
        let up = MTRFavorite(lineID: "TWL", stationID: "ADM", direction: "UP")
        let down = MTRFavorite(lineID: "TWL", stationID: "ADM", direction: "DOWN")
        let otherLine = MTRFavorite(lineID: "ISL", stationID: "ADM", direction: "UP")
        var stored = MTRFavorite.toggling(up, in: "")
        stored = MTRFavorite.toggling(down, in: stored)
        stored = MTRFavorite.toggling(otherLine, in: stored)
        precondition(MTRFavorite.decode(stored) == [up, down, otherLine])
        precondition(MTRFavorite.decode(stored + "\n" + up.id).count == 3)
        let removed = MTRFavorite.toggling(up, in: stored)
        precondition(MTRFavorite.decode(removed) == [down, otherLine])
        precondition(MTRFavorite.decode(MTRFavorite.removing(down, from: removed)) == [otherLine])
        precondition(MTRFavorite.decode("bad\nTWL||UP\nTWL|ADM|INVALID").isEmpty)
        precondition(MTRFavorite.toggling(up, in: "future-record").contains("future-record"))
        let defaults = UserDefaults(suiteName: "MTRFavoriteChecks." + UUID().uuidString)!
        defaults.set(stored, forKey: MTRFavorite.storageKey)
        precondition(MTRFavorite.decode(defaults.string(forKey: MTRFavorite.storageKey)!) == [up, down, otherLine])
        defaults.removeObject(forKey: MTRFavorite.storageKey)
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        for favorite in [up, down, otherLine] {
            let patterns = try MTRStations.parse(csv, line: favorite.lineID)
            precondition(patterns.contains {
                MTRTravelDirection(patternID: $0.id).rawValue == favorite.direction &&
                $0.stations.contains { $0.id == favorite.stationID }
            })
        }
        print("MTR favorite checks passed: persistence, separate lines/directions, duplicates, removal and restoration.")
    }
}
