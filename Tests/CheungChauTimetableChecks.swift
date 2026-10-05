import Foundation

@main
struct CheungChauTimetableChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let timetable = try CheungChauTimetable(csv: csv)
        precondition(timetable.sailings.count == 164)
        let expected: [(Bool, FerryServiceDay, CheungChauFerryType, Int)] = [
            (true, .weekday, .fast, 24), (true, .weekday, .ordinary, 19),
            (false, .weekday, .fast, 25), (false, .weekday, .ordinary, 19),
            (true, .holiday, .fast, 21), (true, .holiday, .ordinary, 18),
            (false, .holiday, .fast, 20), (false, .holiday, .ordinary, 18)
        ]
        for item in expected {
            precondition(timetable.departures(fromCentral: item.0, day: item.1, type: item.2).count == item.3)
        }
        let nextDay = timetable.sailings.filter(\.nextDay)
        precondition(nextDay.count == 2 && nextDay.allSatisfy { $0.clock == "00:30" && $0.type == .fast })
        precondition(nextDay.first { $0.day == .weekday }?.operatingNote == .largeVesselWeekdays)
        precondition(nextDay.first { $0.day == .holiday }?.operatingNote == CheungChauOperatingNote.none)
        precondition(timetable.sailings.filter { $0.operatingNote == .saturdayOnly }.count == 1)
        precondition(timetable.sailings.filter { $0.operatingNote == .weekdaysOnly }.count == 4)
        precondition(timetable.sailings.filter { $0.operatingNote == .largeVesselWeekdays }.count == 2)

        let quoted = "Direction,Service Date,Service Hour,Remark\n\"Central to Cheung Chau\",Mondays to Saturdays except public holidays,1:30 a.m.,\n"
        do { _ = try CheungChauTimetable(csv: quoted); preconditionFailure("Incomplete groups must fail") }
        catch CheungChauTimetable.DataError.unsupportedRecord { }
        let invalid = csv.replacingOccurrences(of: ",1.0", with: ",99.0", options: [], range: csv.range(of: ",1.0"))
        do { _ = try CheungChauTimetable(csv: invalid); preconditionFailure("Unknown remarks must fail") }
        catch CheungChauTimetable.DataError.unsupportedRecord { }
        print("Cheung Chau timetable checks passed.")
    }
}
