import Foundation

enum FerryServiceDay: String, CaseIterable, Identifiable {
    case weekday = "Mondays to Saturdays except public holidays"
    case holiday = "Sundays and public holidays"
    var id: String { rawValue }
}

struct PengChauSailing: Identifiable {
    let id: Int
    let fromCentral: Bool
    let day: FerryServiceDay
    let minutes: Int
    let nextDay: Bool

    var clock: String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    var serviceMinutes: Int { minutes + (nextDay ? 1440 : 0) }
}

struct PengChauTimetable {
    let sailings: [PengChauSailing]
    enum DataError: Error { case missingFile, invalidCSV, unsupportedRecord }

    static func load() throws -> Self {
        guard let url = Bundle.main.url(forResource: "PengChauTimetable", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try Self(csv: String(contentsOf: url, encoding: .utf8))
    }

    init(csv: String) throws {
        let lines = csv.replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let header = lines.first,
              try Self.fields(header) == ["Direction", "Service Date", "Service Hour", "Remark"] else {
            throw DataError.invalidCSV
        }
        var result: [PengChauSailing] = []
        for (index, line) in lines.dropFirst().enumerated() {
            let values = try Self.fields(line)
            guard values.count == 4 else { throw DataError.invalidCSV }
            // Explicit route whitelist: never mix the Hei Ling Chau branch into this connection.
            guard ["Central to Peng Chau", "Peng Chau to Central"].contains(values[0]) else { continue }
            guard let day = FerryServiceDay(rawValue: values[1]),
                  ["", "1", "1.0"].contains(values[3]) else { throw DataError.unsupportedRecord }
            result.append(PengChauSailing(id: index, fromCentral: values[0] == "Central to Peng Chau",
                                         day: day, minutes: try Self.minutes(values[2]), nextDay: !values[3].isEmpty))
        }
        // Fail closed if a direction/day table is absent, rather than implying no service.
        for fromCentral in [true, false] {
            for day in FerryServiceDay.allCases {
                guard result.contains(where: { $0.fromCentral == fromCentral && $0.day == day }) else {
                    throw DataError.unsupportedRecord
                }
            }
        }
        sailings = result
    }

    func departures(fromCentral: Bool, day: FerryServiceDay) -> [PengChauSailing] {
        sailings.filter { $0.fromCentral == fromCentral && $0.day == day }
            .sorted { $0.serviceMinutes < $1.serviceMinutes }
    }

    private static func minutes(_ value: String) throws -> Int {
        let pieces = value.split(separator: " ")
        guard pieces.count == 2 else { throw DataError.unsupportedRecord }
        let clock = pieces[0].split(separator: ":")
        guard clock.count == 2, let hour = Int(clock[0]), let minute = Int(clock[1]),
              (1...12).contains(hour), (0...59).contains(minute) else { throw DataError.unsupportedRecord }
        switch pieces[1] {
        case "a.m.": return (hour % 12) * 60 + minute
        case "p.m.": return (hour % 12 + 12) * 60 + minute
        case "noon" where hour == 12 && minute == 0: return 720
        default: throw DataError.unsupportedRecord
        }
    }

    private static func fields(_ line: String) throws -> [String] {
        var fields: [String] = [], field = "", quoted = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i + 1 < chars.count && chars[i + 1] == "\"" {
                    field.append("\""); i += 1
                } else { quoted.toggle() }
            } else if c == "," && !quoted {
                fields.append(field.trimmingCharacters(in: .whitespaces)); field = ""
            } else { field.append(c) }
            i += 1
        }
        guard !quoted else { throw DataError.invalidCSV }
        fields.append(field.trimmingCharacters(in: .whitespaces))
        return fields
    }
}
