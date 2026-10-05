import Foundation

struct MTRAdultFare {
    let octopus: Decimal
    let singleJourney: Decimal
}

enum MTRFares {
    enum DataError: Error { case missingFile, invalidRow }
    static func key(from: Int, to: Int) -> String { "\(from)|\(to)" }

    static func load(airportExpress: Bool) throws -> [String: MTRAdultFare] {
        let file = airportExpress ? "AirportExpressAdultFares" : "MTRAdultFares"
        guard let url = Bundle.main.url(forResource: file, withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try parse(String(contentsOf: url, encoding: .utf8))
    }

    static func parse(_ csv: String) throws -> [String: MTRAdultFare] {
        var result: [String: MTRAdultFare] = [:]
        var seen = Set<String>()
        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let f = row.components(separatedBy: ",")
            guard f.count == 4, let from = Int(f[0]), let to = Int(f[1]), from > 0, to > 0,
                  let octopus = amount(f[2]), let single = amount(f[3]) else {
                throw DataError.invalidRow
            }
            let pair = key(from: from, to: to)
            guard seen.insert(pair).inserted else { throw DataError.invalidRow }
            // Self entries and zero walking-link placeholders are not rail fares.
            guard from != to, octopus > 0, single > 0 else { continue }
            result[pair] = MTRAdultFare(octopus: octopus, singleJourney: single)
        }
        return result
    }

    static func destinations(from origin: MTRFareStation, stations: [MTRFareStation],
                             fares: [String: MTRAdultFare]) -> [MTRFareStation] {
        stations.filter {
            $0.fareID != origin.fareID && fares[key(from: origin.fareID, to: $0.fareID)] != nil
        }
    }

    private static func amount(_ value: String) -> Decimal? {
        guard value.range(of: "^[0-9]+(\\.[0-9]+)?$", options: .regularExpression) != nil,
              let amount = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")),
              !amount.isNaN else { return nil }
        return amount
    }
}
