import Foundation

enum YungShueWanOperatingNote: String {
    case none
    case saturdayOnly
}

struct YungShueWanSailing: Identifiable {
    let id: Int
    let fromCentral: Bool
    let day: FerryServiceDay
    let minutes: Int
    let operatingNote: YungShueWanOperatingNote
    let nextDay: Bool

    var clock: String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
    var serviceMinutes: Int { minutes + (nextDay ? 1440 : 0) }
}

struct YungShueWanTimetable {
    let sailings: [YungShueWanSailing]
    enum DataError: Error { case missingFile, invalidCSV, unsupportedRecord }

    static func load() throws -> Self {
        guard let url = Bundle.main.url(forResource: "YungShueWanTimetable", withExtension: "csv") else {
            throw DataError.missingFile
        }
        return try Self(csv: String(contentsOf: url, encoding: .utf8))
    }

    init(csv: String) throws {
        let lines = csv.replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let header = lines.first,
              try Self.fields(header) == ["Direction", "Service Date", "Timetable", "Remark"] else {
            throw DataError.invalidCSV
        }

        var result: [YungShueWanSailing] = []
        for (index, line) in lines.dropFirst().enumerated() {
            let values = try Self.fields(line)
            guard values.count == 4,
                  ["Central to Yung Shue Wan", "Yung Shue Wan to Central"].contains(values[0]),
                  let day = FerryServiceDay(rawValue: values[1]) else {
                throw DataError.unsupportedRecord
            }

            let note: YungShueWanOperatingNote
            let nextDay: Bool
            switch values[3] {
            case "": note = .none; nextDay = false
            case "1", "1.0": note = .saturdayOnly; nextDay = false
            case "2", "2.0": note = .none; nextDay = true
            default: throw DataError.unsupportedRecord
            }

            result.append(.init(id: index,
                                fromCentral: values[0] == "Central to Yung Shue Wan",
                                day: day,
                                minutes: try Self.minutes(values[2]),
                                operatingNote: note,
                                nextDay: nextDay))
        }

        for fromCentral in [true, false] {
            for day in FerryServiceDay.allCases {
                guard result.contains(where: { $0.fromCentral == fromCentral && $0.day == day }) else {
                    throw DataError.unsupportedRecord
                }
            }
        }
        sailings = result
    }

    func departures(fromCentral: Bool, day: FerryServiceDay) -> [YungShueWanSailing] {
        sailings.filter { $0.fromCentral == fromCentral && $0.day == day }
            .sorted { $0.serviceMinutes < $1.serviceMinutes }
    }

    private static func minutes(_ value: String) throws -> Int {
        let pieces = value.split(separator: " ")
        guard pieces.count == 2 else { throw DataError.unsupportedRecord }
        let clock = pieces[0].split(separator: ":")
        guard clock.count == 2, let hour = Int(clock[0]), let minute = Int(clock[1]),
              (1...12).contains(hour), (0...59).contains(minute) else {
            throw DataError.unsupportedRecord
        }
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
