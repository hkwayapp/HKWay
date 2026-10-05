import Foundation

enum CheungChauFerryType: String, CaseIterable, Identifiable {
    case fast = "Fast Ferry"
    case ordinary = "Ordinary Ferry"
    var id: Self { self }
}

enum CheungChauOperatingNote: String {
    case none, weekdaysOnly, saturdayOnly, largeVesselWeekdays
}

struct CheungChauSailing: Identifiable {
    let id: Int
    let fromCentral: Bool
    let day: FerryServiceDay
    let minutes: Int
    let type: CheungChauFerryType
    let operatingNote: CheungChauOperatingNote
    let nextDay: Bool

    var clock: String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    var serviceMinutes: Int { minutes + (nextDay ? 1440 : 0) }
}

struct CheungChauTimetable {
    let sailings: [CheungChauSailing]
    enum DataError: Error { case missingFile, invalidCSV, unsupportedRecord }

    static func load() throws -> Self {
        guard let url = Bundle.main.url(forResource: "CheungChauTimetable", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try Self(csv: String(contentsOf: url, encoding: .utf8))
    }

    init(csv: String) throws {
        let lines = csv.replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let header = lines.first,
              try Self.fields(header) == ["Direction", "Service Date", "Service Hour", "Remark"] else {
            throw DataError.invalidCSV
        }
        var result: [CheungChauSailing] = []
        for (index, line) in lines.dropFirst().enumerated() {
            let values = try Self.fields(line)
            guard values.count == 4,
                  ["Central to Cheung Chau", "Cheung Chau to Central"].contains(values[0]),
                  let day = FerryServiceDay(rawValue: values[1]) else {
                throw DataError.unsupportedRecord
            }
            let marker = values[3]
            let type: CheungChauFerryType
            let note: CheungChauOperatingNote
            let nextDay: Bool
            switch marker {
            case "": type = .fast; note = .none; nextDay = false
            case "1", "1.0": type = .ordinary; note = .none; nextDay = false
            case "2", "2.0": type = .fast; note = .weekdaysOnly; nextDay = false
            case "3", "3.0": type = .ordinary; note = .saturdayOnly; nextDay = false
            case "4", "4.0": type = .ordinary; note = .weekdaysOnly; nextDay = false
            case "5", "5.0": type = .fast; note = .largeVesselWeekdays; nextDay = false
            case "6", "6.0":
                type = .fast
                note = day == .weekday ? .largeVesselWeekdays : .none
                nextDay = true
            default: throw DataError.unsupportedRecord
            }
            result.append(.init(id: index, fromCentral: values[0] == "Central to Cheung Chau",
                                day: day, minutes: try Self.minutes(values[2]), type: type,
                                operatingNote: note, nextDay: nextDay))
        }
        for fromCentral in [true, false] {
            for day in FerryServiceDay.allCases {
                for type in CheungChauFerryType.allCases {
                    guard result.contains(where: { $0.fromCentral == fromCentral && $0.day == day && $0.type == type }) else {
                        throw DataError.unsupportedRecord
                    }
                }
            }
        }
        sailings = result
    }

    func departures(fromCentral: Bool, day: FerryServiceDay,
                    type: CheungChauFerryType) -> [CheungChauSailing] {
        sailings.filter { $0.fromCentral == fromCentral && $0.day == day && $0.type == type }
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
        var result: [String] = [], field = "", quoted = false
        let characters = Array(line)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted && index + 1 < characters.count && characters[index + 1] == "\"" {
                    field.append("\""); index += 1
                } else { quoted.toggle() }
            } else if character == "," && !quoted {
                result.append(field.trimmingCharacters(in: .whitespaces)); field = ""
            } else { field.append(character) }
            index += 1
        }
        guard !quoted else { throw DataError.invalidCSV }
        result.append(field.trimmingCharacters(in: .whitespaces))
        return result
    }
}
