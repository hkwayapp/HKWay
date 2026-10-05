import Foundation

struct LightRailStop {
    let stationID: Int
    let english: String
    let traditional: String
    let simplified: String

    // Direct Tuen Ma connections: Siu Hong, Tuen Mun, Tin Shui Wai, Yuen Long.
    // Confirmed 2026-08-31: https://www.mtr.com.hk/en/customer/services/lt_bus_index.html
    var hasTuenMaInterchange: Bool {
        tuenMaStationCode != nil
    }

    var tuenMaStationCode: String? {
        switch stationID {
        case 100: "SIH"
        case 295: "TUM"
        case 430: "TIS"
        case 600: "YUL"
        default: nil
        }
    }
}

struct LightRailJourney: Identifiable {
    let id: String
    let stops: [LightRailStop]
}

enum LightRailStops {
    enum DataError: Error { case missingFile, invalidRow, missingRoute }

    static func routeIDs(mtrStationCode: String) -> [String]? {
        switch mtrStationCode {
        case "YUL": ["610", "614", "615", "761P"]
        case "TIS": ["705", "706", "751"]
        case "TUM": ["505", "507", "751"]
        case "SIH": ["505", "610", "614", "614P", "615", "615P", "751"]
        default: nil
        }
    }

    static func load(routeID: String) throws -> [LightRailJourney] {
        guard let url = Bundle.main.url(forResource: "LightRailStops", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try parse(String(contentsOf: url, encoding: .utf8), routeID: routeID)
    }

    // MTR official CSV, retrieved 2026-08-31 (published 2026-07-05).
    // https://opendata.mtr.com.hk/data/light_rail_routes_and_stops.csv
    // Its seven columns contain no platform numbers. Preserve station IDs for ETA.
    static func parse(_ csv: String, routeID: String) throws -> [LightRailJourney] {
        var directions: [Int: [(Int, LightRailStop)]] = [:]
        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let fields = row.components(separatedBy: ",")
            guard fields.count == 7 else { throw DataError.invalidRow }
            guard fields[0] == routeID else { continue }
            guard let direction = Int(fields[1]), let stationID = Int(fields[3]),
                  let sequence = Int(fields[6]) else { throw DataError.invalidRow }
            let stop = LightRailStop(
                stationID: stationID, english: fields[5], traditional: fields[4],
                simplified: fields[4].applyingTransform(
                    StringTransform("Traditional-Simplified"), reverse: false
                ) ?? fields[4]
            )
            directions[direction, default: []].append((sequence, stop))
        }
        guard !directions.isEmpty else { throw DataError.missingRoute }
        let journeys = directions.keys.sorted().map { direction in
            LightRailJourney(id: String(direction), stops: removeConsecutiveDuplicates(
                directions[direction]!.sorted { $0.0 < $1.0 }.map(\.1)
            ))
        }
        if routeID == "705" || routeID == "706" {
            // These are sequential loop sections, NOT reverse directions.
            // Remove the repeated junction only; retain the final return to origin.
            return [LightRailJourney(id: "loop", stops: removeConsecutiveDuplicates(
                journeys.flatMap(\.stops)
            ))]
        }
        return journeys
    }

    private static func removeConsecutiveDuplicates(_ stops: [LightRailStop]) -> [LightRailStop] {
        stops.reduce(into: []) { result, stop in
            if result.last?.stationID != stop.stationID { result.append(stop) }
        }
    }
}
