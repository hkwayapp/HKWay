import Foundation

@main
struct MuiWoTimetableChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let timetable = try MuiWoTimetable(csv: csv)
        precondition(timetable.sailings.count == 113)
        precondition(timetable.departures(fromCentral: true, day: .weekday, type: .fast).count == 29)
        precondition(timetable.departures(fromCentral: true, day: .weekday, type: .ordinary).count == 1)
        precondition(timetable.departures(fromCentral: false, day: .weekday, type: .fast).count == 28)
        precondition(timetable.departures(fromCentral: false, day: .weekday, type: .ordinary).count == 1)
        precondition(timetable.departures(fromCentral: true, day: .holiday, type: .fast).count == 26)
        precondition(timetable.departures(fromCentral: true, day: .holiday, type: .ordinary).count == 1)
        precondition(timetable.departures(fromCentral: false, day: .holiday, type: .fast).count == 27)
        precondition(timetable.departures(fromCentral: false, day: .holiday, type: .ordinary).isEmpty)
        let nextDay = timetable.sailings.filter(\.nextDay)
        precondition(nextDay.count == 2 && nextDay.allSatisfy { $0.clock == "00:30" })
        let via = timetable.sailings.filter { $0.operatingNote == .viaPengChau }
        precondition(via.count == 1 && !via[0].fromCentral && via[0].clock == "08:30")
        let invalid = csv.replacingOccurrences(of: ",2.0", with: ",99.0", options: [], range: csv.range(of: ",2.0"))
        do { _ = try MuiWoTimetable(csv: invalid); preconditionFailure("Unknown marker must fail") }
        catch MuiWoTimetable.DataError.unsupportedRecord { }
        print("Mui Wo timetable checks passed.")
    }
}
