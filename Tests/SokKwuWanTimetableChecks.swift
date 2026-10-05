import Foundation

@main
struct SokKwuWanTimetableChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let timetable = try SokKwuWanTimetable(csv: csv)
        precondition(timetable.sailings.count == 54)
        precondition(timetable.departures(fromCentral: true, day: .weekday).count == 11)
        precondition(timetable.departures(fromCentral: false, day: .weekday).count == 11)
        precondition(timetable.departures(fromCentral: true, day: .holiday).count == 16)
        precondition(timetable.departures(fromCentral: false, day: .holiday).count == 16)
        precondition(timetable.sailings.filter(\.subjectToDemand).count == 10)
        precondition(timetable.sailings.filter(\.subjectToDemand).allSatisfy { $0.day == .holiday })

        let invalid = csv.replacingOccurrences(of: ",1.0", with: ",99.0", options: [], range: csv.range(of: ",1.0"))
        do { _ = try SokKwuWanTimetable(csv: invalid); preconditionFailure("Unknown marker must fail") }
        catch SokKwuWanTimetable.DataError.unsupportedRecord { }
        print("Sok Kwu Wan timetable checks passed.")
    }
}
