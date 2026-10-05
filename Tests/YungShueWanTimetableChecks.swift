import Foundation

@main
struct YungShueWanTimetableChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let timetable = try YungShueWanTimetable(csv: csv)
        precondition(timetable.sailings.count == 127)
        precondition(timetable.departures(fromCentral: true, day: .weekday).count == 33)
        precondition(timetable.departures(fromCentral: false, day: .weekday).count == 32)
        precondition(timetable.departures(fromCentral: true, day: .holiday).count == 31)
        precondition(timetable.departures(fromCentral: false, day: .holiday).count == 31)

        let saturday = timetable.sailings.filter { $0.operatingNote == .saturdayOnly }
        precondition(saturday.count == 1 && saturday[0].fromCentral && saturday[0].clock == "02:30")
        let nextDay = timetable.sailings.filter(\.nextDay)
        precondition(nextDay.count == 2 && nextDay.allSatisfy { $0.fromCentral && $0.clock == "00:30" })

        let invalid = csv.replacingOccurrences(of: ",1.0", with: ",99.0", options: [], range: csv.range(of: ",1.0"))
        do { _ = try YungShueWanTimetable(csv: invalid); preconditionFailure("Unknown marker must fail") }
        catch YungShueWanTimetable.DataError.unsupportedRecord { }
        print("Yung Shue Wan timetable checks passed.")
    }
}
