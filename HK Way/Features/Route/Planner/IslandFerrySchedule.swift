//
//  IslandFerrySchedule.swift
//  HK Way
//

import Foundation

struct IslandFerryDeparture: Identifiable, Equatable {
    let id: String
    let departureMinutes: Int
    let serviceMinutes: Int
    let serviceDescription: String
    let referenceDurationMinutes: Int?

    var departureDate: Date {
        Calendar.current.startOfDay(for: .now)
            .addingTimeInterval(TimeInterval(serviceMinutes * 60))
    }
}

enum IslandFerrySchedule {
    static func nextDeparture(
        to destination: IslandPlannerDestination,
        after date: Date
    ) throws -> IslandFerryDeparture? {
        let calendar = Calendar.current
        let day = calendar.isDateInWeekend(date) ? FerryServiceDay.holiday : .weekday
        let startOfDay = calendar.startOfDay(for: date)
        let requiredMinutes = Int(date.timeIntervalSince(startOfDay) / 60)

        return try departures(to: destination, day: day)
            .first { $0.serviceMinutes >= requiredMinutes }
    }

    static func departures(
        to destination: IslandPlannerDestination,
        day: FerryServiceDay
    ) throws -> [IslandFerryDeparture] {
        switch destination {
        case .yungShueWan:
            return try YungShueWanTimetable.load().departures(fromCentral: true, day: day).map {
                .init(id: "ysw-\($0.id)", departureMinutes: $0.minutes,
                      serviceMinutes: $0.serviceMinutes, serviceDescription: "Ferry",
                      referenceDurationMinutes: 27)
            }
        case .sokKwuWan:
            return try SokKwuWanTimetable.load().departures(fromCentral: true, day: day).map {
                .init(id: "skw-\($0.id)", departureMinutes: $0.minutes,
                      serviceMinutes: $0.minutes, serviceDescription: $0.subjectToDemand ? "Conditional ferry" : "Ferry",
                      referenceDurationMinutes: nil)
            }
        case .cheungChau:
            let table = try CheungChauTimetable.load()
            return CheungChauFerryType.allCases.flatMap { type in
                table.departures(fromCentral: true, day: day, type: type).map {
                    .init(id: "cc-\($0.id)", departureMinutes: $0.minutes,
                          serviceMinutes: $0.serviceMinutes, serviceDescription: type.rawValue,
                          referenceDurationMinutes: nil)
                }
            }.sorted { $0.serviceMinutes < $1.serviceMinutes }
        case .muiWo:
            let table = try MuiWoTimetable.load()
            return CheungChauFerryType.allCases.flatMap { type in
                table.departures(fromCentral: true, day: day, type: type).map {
                    .init(id: "mw-\($0.id)", departureMinutes: $0.minutes,
                          serviceMinutes: $0.serviceMinutes, serviceDescription: type.rawValue,
                          referenceDurationMinutes: nil)
                }
            }.sorted { $0.serviceMinutes < $1.serviceMinutes }
        case .pengChau:
            return try PengChauTimetable.load().departures(fromCentral: true, day: day).map {
                .init(id: "pc-\($0.id)", departureMinutes: $0.minutes,
                      serviceMinutes: $0.serviceMinutes, serviceDescription: "Ferry",
                      referenceDurationMinutes: nil)
            }
        }
    }
}
