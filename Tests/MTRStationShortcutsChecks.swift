import Foundation

@main enum MTRStationShortcutsChecks {
    static func main() throws {
        var history = ""
        for id in ["TSW", "ADM", "DIS", "SUN", "TKO", "POA", "LHP", "HOK", "TUC", "LOW", "LMC"] {
            history = MTRStationShortcuts.recording(id, in: history)
        }
        precondition(MTRStationShortcuts.recentLimit == 10)
        precondition(MTRStationShortcuts.recentIDs(history) == ["LMC", "LOW", "TUC", "HOK", "LHP", "POA", "TKO", "SUN", "DIS", "ADM"])
        history = MTRStationShortcuts.recording("DIS", in: history)
        precondition(MTRStationShortcuts.recentIDs(history) == ["DIS", "LMC", "LOW", "TUC", "HOK", "LHP", "POA", "TKO", "SUN", "ADM"])
        precondition(MTRStationShortcuts.recording("invalid|value", in: history) == history)
        precondition(MTRStationShortcuts.recentIDs("ADM\nADM\n\ninvalid value\nDIS") == ["ADM", "DIS"])
        let csv = try String(contentsOfFile: "HK Way/Resources/MTRStations.csv", encoding: .utf8)
        let stations = try MTRStations.fareStations(csv, airportExpress: false).map(\.station)
        let favorites = "TWL|ADM|UP\nTWL|ADM|DOWN\nISL|ADM|UP\nDRL|DIS|DOWN\nAEL|AIR|UP\nBAD|ZZZ|UP"
        precondition(MTRStationShortcuts.favorites(favorites, stations: stations).map(\.id) == ["ADM", "DIS"])
        precondition(MTRStationShortcuts.resolve(["ZZZ", "DIS", "DIS", "ADM"], stations: stations).map(\.id) == ["DIS", "ADM"])
        let suite = "MTRStationShortcutsChecks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(history, forKey: MTRStationShortcuts.recentStorageKey)
        defaults.set(favorites, forKey: MTRFavorite.storageKey)
        let reopened = UserDefaults(suiteName: suite)!
        precondition(reopened.string(forKey: MTRStationShortcuts.recentStorageKey) == history)
        reopened.set("", forKey: MTRStationShortcuts.recentStorageKey)
        precondition(reopened.string(forKey: MTRFavorite.storageKey) == favorites)
        precondition(MTRStationShortcuts.recentIDs(reopened.string(forKey: MTRStationShortcuts.recentStorageKey)!).isEmpty)
        print("Station shortcut checks passed: recent ordering/limit, deduplication, supported stations, persistence and independent clearing.")
    }
}
