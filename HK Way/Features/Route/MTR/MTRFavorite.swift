import Foundation

struct MTRFavorite: Identifiable, Equatable {
    static let storageKey = "favoriteMTRStations.v1"
    let lineID: String
    let stationID: String
    let direction: String
    var id: String { "\(lineID)|\(stationID)|\(direction)" }

    static func decode(_ value: String) -> [Self] {
        var seen = Set<String>()
        return value.split(separator: "\n").compactMap { row in
            let fields = row.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3,
                  fields[0].range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil,
                  fields[1].range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil,
                  ["UP", "DOWN"].contains(fields[2]), seen.insert(String(row)).inserted else { return nil }
            return Self(lineID: fields[0], stationID: fields[1], direction: fields[2])
        }
    }

    static func toggling(_ favorite: Self, in value: String) -> String {
        let rows = value.split(separator: "\n").map(String.init)
        // Keep unrelated records intact, including records from a newer version.
        return (rows.contains(favorite.id) ? rows.filter { $0 != favorite.id } : rows + [favorite.id])
            .joined(separator: "\n")
    }

    static func removing(_ favorite: Self, from value: String) -> String {
        value.split(separator: "\n").filter { $0 != favorite.id }.joined(separator: "\n")
    }
}
