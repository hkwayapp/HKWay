import Foundation

@main
struct KaiTakEventArrangementChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2))!
        let source = URL(string: "https://www.td.gov.hk/")!

        func event(_ id: String, start: (Int, Int, Int), end: (Int, Int, Int)) -> KaiTakEventArrangement {
            KaiTakEventArrangement(
                id: id,
                venue: .stadium,
                title: id,
                startDate: calendar.date(from: DateComponents(year: start.0, month: start.1, day: start.2))!,
                endDate: calendar.date(from: DateComponents(year: end.0, month: end.1, day: end.2))!,
                sourceURL: source,
                services: []
            )
        }

        let result = KaiTakEventArrangement.current(from: [
            event("expired", start: (2026, 8, 30), end: (2026, 9, 1)),
            event("today", start: (2026, 9, 2), end: (2026, 9, 2)),
            event("later", start: (2026, 9, 8), end: (2026, 9, 8))
        ], now: now, calendar: calendar)

        precondition(result.map(\.id) == ["today", "later"])
        precondition(KaiTakSpecialRoute.catalogue.count == 12)
        precondition(Set(KaiTakSpecialRoute.catalogue.map(\.id)).count == 12)
        precondition(KaiTakSpecialRoute.catalogue.allSatisfy { $0.number.hasPrefix("SP") })
        precondition(KaiTakSpecialRoute.catalogue.first { $0.number == "SP2" }?.destinationEnglish == "Prince Edward · Mong Kok")
        precondition(KaiTakSpecialRoute.catalogue.first { $0.number == "SP7" }?.destinationTraditional.contains("上水") == true)
        precondition(KaiTakSpecialRoute.Operator.kmb.displayName(for: .english) == "KMB")
        precondition(KaiTakSpecialRoute.Operator.kmb.displayName(for: .traditionalChinese) == "九巴")
        precondition(KaiTakSpecialRoute.Operator.citybus.displayName(for: .simplifiedChinese) == "城巴")
        precondition(KaiTakSpecialRoute.Operator.kmbAndCitybus.displayName(for: .traditionalChinese) == "九巴 / 城巴")
        print("Kai Tak checks passed: expiry filtering and 12 localized SP catalogue entries")
    }
}
