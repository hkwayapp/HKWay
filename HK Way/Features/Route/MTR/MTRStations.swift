import Foundation

struct MTRStation: Identifiable, Hashable, Sendable {
    let id: String
    let traditional: String
    let english: String
    var simplified: String {
        traditional.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? traditional
    }
}

struct MTRStationPattern: Identifiable, Sendable {
    let id: String
    let stations: [MTRStation]
}

struct MTRFareStation: Identifiable {
    let fareID: Int
    let station: MTRStation
    var id: String { station.id }
}

enum MTRStations {
    enum DataError: Error { case missingFile, invalidRow, missingLine }

    static func loadFareStations(airportExpress: Bool) throws -> [MTRFareStation] {
        guard let url = Bundle.main.url(forResource: "MTRStations", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try fareStations(String(contentsOf: url, encoding: .utf8), airportExpress: airportExpress)
    }

    static func fareStations(_ csv: String, airportExpress: Bool) throws -> [MTRFareStation] {
        var result: [String: MTRFareStation] = [:]
        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let fields = try columns(row)
            if fields.allSatisfy({ $0.isEmpty }) { continue }
            guard fields.count == 7 else { throw DataError.invalidRow }
            guard (fields[0] == "AEL") == airportExpress else { continue }
            guard let fareID = Int(fields[3]), fareID > 0 else { throw DataError.invalidRow }
            let code = fields[2]
            if let prior = result[code], prior.fareID != fareID { throw DataError.invalidRow }
            result[code] = MTRFareStation(fareID: fareID, station: MTRStation(
                id: code, traditional: fields[4], english: fields[5]
            ))
        }
        return result.values.sorted { $0.station.english.localizedStandardCompare($1.station.english) == .orderedAscending }
    }

    static func load(line: String) throws -> [MTRStationPattern] {
        guard let url = Bundle.main.url(forResource: "MTRStations", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try parse(String(contentsOf: url, encoding: .utf8), line: line)
    }

    static func loadStationLines() throws -> [String: Set<String>] {
        guard let url = Bundle.main.url(forResource: "MTRStations", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try stationLines(String(contentsOf: url, encoding: .utf8))
    }

    // Match shared station codes only. Different-code walking connections must
    // be verified separately; do not infer them from names or proximity.
    static func stationLines(_ csv: String) throws -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let fields = try columns(row)
            if fields.allSatisfy({ $0.isEmpty }) { continue }
            guard fields.count == 7, !fields[0].isEmpty, !fields[2].isEmpty else {
                throw DataError.invalidRow
            }
            result[fields[2], default: []].insert(fields[0])
        }
        return result
    }

    static func parse(_ csv: String, line: String) throws -> [MTRStationPattern] {
        var groups: [String: [(Double, MTRStation)]] = [:]
        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let fields = try columns(row)
            if fields.allSatisfy({ $0.isEmpty }) { continue }
            guard fields.count == 7 else { throw DataError.invalidRow }
            guard fields[0] == line else { continue }
            guard !fields[1].isEmpty, !fields[2].isEmpty,
                  let sequence = Double(fields[6]), sequence.isFinite, sequence > 0 else {
                throw DataError.invalidRow
            }
            groups[fields[1], default: []].append((sequence, MTRStation(
                id: fields[2], traditional: fields[4], english: fields[5]
            )))
        }
        guard !groups.isEmpty else { throw DataError.missingLine }
        return try groups.keys.sorted().map { direction in
            let rows = groups[direction]!.sorted { $0.0 < $1.0 }
            guard Set(rows.map { $0.0 }).count == rows.count,
                  Set(rows.map { $0.1.id }).count == rows.count else { throw DataError.invalidRow }
            return MTRStationPattern(id: direction, stations: rows.map { $0.1 })
        }
    }

    private static func columns(_ row: String) throws -> [String] {
        var result: [String] = []
        var value = ""
        var quoted = false
        // Toggle quotes; doubled quotes contribute one literal quote.
        let chars = Array(row)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "\"" {
                if quoted && index + 1 < chars.count && chars[index + 1] == "\"" {
                    value.append("\"")
                    index += 1
                } else { quoted.toggle() }
            } else if char == "," && !quoted {
                result.append(value); value = ""
            } else { value.append(char) }
            index += 1
        }
        guard !quoted else { throw DataError.invalidRow }
        result.append(value)
        return result
    }
}
