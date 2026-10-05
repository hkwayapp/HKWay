import Foundation

struct LightRailAdultFare {
    let octopus: Decimal
    let singleJourney: Decimal
}

enum LightRailFares {
    enum DataError: Error { case missingFile, invalidRow }

    // Adult columns extracted without price changes from MTR's official CSV:
    // https://opendata.mtr.com.hk/data/light_rail_fares.csv
    // Retrieved 2026-08-31; this is NOT an assertion of an effective fare date.
    static func load() throws -> [String: LightRailAdultFare] {
        guard let url = Bundle.main.url(forResource: "LightRailAdultFares", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try parse(String(contentsOf: url, encoding: .utf8))
    }

    static func key(from: Int, to: Int) -> String { "\(from)|\(to)" }

    static func parse(_ csv: String) throws -> [String: LightRailAdultFare] {
        var fares: [String: LightRailAdultFare] = [:]
        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let fields = row.components(separatedBy: ",")
            guard fields.count == 4,
                  let from = Int(fields[0]), let to = Int(fields[1]),
                  let octopus = Decimal(string: fields[2], locale: Locale(identifier: "en_US_POSIX")),
                  let single = Decimal(string: fields[3], locale: Locale(identifier: "en_US_POSIX")),
                  octopus >= 0, single >= 0 else { throw DataError.invalidRow }
            guard from != to else { continue } // Same-stop zeros are not a free circular journey.
            fares[key(from: from, to: to)] = LightRailAdultFare(octopus: octopus, singleJourney: single)
        }
        return fares
    }
}

extension LightRailJourney {
    func destinations(after index: Int) -> [LightRailStop] {
        guard stops.indices.contains(index) else { return [] }
        guard id == "loop" else { return Array(stops.dropFirst(index + 1)) }
        let loop = Array(stops.dropLast())
        guard !loop.isEmpty else { return [] }
        let start = index % loop.count
        return (1..<loop.count).map { loop[(start + $0) % loop.count] }
    }
}
