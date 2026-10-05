import Foundation

enum LightRailStopFavorite {
    static let storageKey = "favoriteLightRailStops.v1"

    static func ids(from value: String) -> Set<Int> {
        Set(value.split(separator: "\n").compactMap { Int($0) })
    }

    static func toggling(_ stationID: Int, in value: String) -> String {
        var ids = ids(from: value)
        if ids.contains(stationID) {
            ids.remove(stationID)
        } else {
            ids.insert(stationID)
        }
        return ids.sorted().map(String.init).joined(separator: "\n")
    }
}

enum LightRailArea: String, CaseIterable, Identifiable {
    case all = "All"
    case tuenMun = "Tuen Mun"
    case tinShuiWai = "Tin Shui Wai"
    case yuenLong = "Yuen Long"
    var id: Self { self }
}

struct LightRailStopCatalogueEntry: Identifiable {
    let stop: LightRailStop
    let routeIDs: [String]
    var id: Int { stop.stationID }

    func otherRouteIDs(excluding currentRoute: String) -> [String] {
        routeIDs.filter { $0 != currentRoute }
    }

    // Familiar geographic browsing areas, not fare zones or district boundaries.
    var area: LightRailArea {
        switch id {
        case 425, 430, 435, 445, 448, 450, 455, 460, 468, 480,
             490, 500, 510, 520, 530, 540, 550: .tinShuiWai
        case 380, 390, 400, 560, 570, 580, 590, 600: .yuenLong
        default: .tuenMun
        }
    }

    func matches(_ query: String) -> Bool {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || [stop.english, stop.traditional, stop.simplified]
            .contains { $0.localizedStandardContains(value) }
    }
}

enum LightRailStopCatalogue {
    static func load() throws -> [LightRailStopCatalogueEntry] {
        guard let url = Bundle.main.url(forResource: "LightRailStops", withExtension: "csv") else {
            throw LightRailStops.DataError.missingFile
        }
        return try parse(String(contentsOf: url, encoding: .utf8))
    }

    static func parse(_ csv: String) throws -> [LightRailStopCatalogueEntry] {
        var stops: [Int: LightRailStop] = [:]
        var routes: [Int: Set<String>] = [:]
        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let fields = row.components(separatedBy: ",")
            guard fields.count == 7, let id = Int(fields[3]) else {
                throw LightRailStops.DataError.invalidRow
            }
            stops[id] = LightRailStop(
                stationID: id, english: fields[5], traditional: fields[4],
                simplified: fields[4].applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? fields[4]
            )
            routes[id, default: []].insert(fields[0])
        }
        return stops.values.map { stop in
            LightRailStopCatalogueEntry(stop: stop, routeIDs: (routes[stop.stationID] ?? []).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            })
        }.sorted { $0.stop.english.localizedStandardCompare($1.stop.english) == .orderedAscending }
    }
}
