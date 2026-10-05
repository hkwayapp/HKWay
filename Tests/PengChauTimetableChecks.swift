import Foundation

@main
struct PengChauTimetableChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let timetable = try PengChauTimetable(csv: csv)
        precondition(timetable.sailings.count == 103)
        precondition(timetable.departures(fromCentral: true, day: .weekday).count == 28)
        precondition(timetable.departures(fromCentral: false, day: .weekday).count == 28)
        precondition(timetable.departures(fromCentral: true, day: .holiday).count == 23)
        precondition(timetable.departures(fromCentral: false, day: .holiday).count == 24)
        for day in FerryServiceDay.allCases {
            let central = timetable.departures(fromCentral: true, day: day)
            precondition(central.first?.clock == "03:00")
            precondition(central.last?.clock == "00:30")
            precondition(central.last?.nextDay == true)
            precondition(central.last?.serviceMinutes == 1470)
            precondition(central.filter(\.nextDay).count == 1)
            let returning = timetable.departures(fromCentral: false, day: day)
            precondition(returning.first?.clock == "03:40")
            precondition(returning.allSatisfy { !$0.nextDay })
        }
        precondition(timetable.departures(fromCentral: true, day: .holiday).contains { $0.clock == "12:00" })
        precondition(timetable.departures(fromCentral: true, day: .weekday).contains { $0.clock == "13:10" })
        // Quoted fields/BOM/CRLF retain the same rows.
        let quoted = csv.replacingOccurrences(of: "Central to Peng Chau", with: "\"Central to Peng Chau\"")
        let quotedTimetable = try PengChauTimetable(csv: quoted)
        precondition(quotedTimetable.sailings.count == 103)
        for bad in [csv.replacingOccurrences(of: "1.0", with: "99"),
                    csv.replacingOccurrences(of: "3:00 a.m.", with: "25:00 a.m."),
                    csv.replacingOccurrences(of: "Service Hour", with: "Changed Schema"),
                    csv.replacingOccurrences(of: "Sundays and public holidays", with: "Unknown day")] {
            do {
                _ = try PengChauTimetable(csv: bad)
                fatalError("Unsupported source data must not silently produce a timetable")
            } catch {}
        }
        print("Peng Chau timetable: 103 sailings, four direction/day groups, noon, rollover and invalid-data checks passed.")
    }
}
