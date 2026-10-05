import Foundation

@main
struct LightRailStopCatalogueChecks {
    static func main() throws {
        let csv = try String(contentsOfFile: "HK Way/Resources/LightRailStops.csv", encoding: .utf8)
        let stops = try LightRailStopCatalogue.parse(csv)
        precondition(stops.count == 68)
        precondition(Set(stops.map(\.id)).count == 68)
        precondition(Set(stops.filter { $0.stop.hasTuenMaInterchange }.map(\.id)) == Set([100, 295, 430, 600]))
        let siuHong = stops.first { $0.id == 100 }!
        precondition(siuHong.routeIDs == ["505", "610", "614", "614P", "615", "615P", "751"])
        precondition(siuHong.otherRouteIDs(excluding: "505") == ["610", "614", "614P", "615", "615P", "751"])
        precondition(stops.allSatisfy { Set($0.routeIDs).count == $0.routeIDs.count })
        let samShing = stops.first { $0.id == 920 }!
        precondition(samShing.otherRouteIDs(excluding: "505").isEmpty)
        precondition(siuHong.area == .tuenMun)
        precondition(siuHong.matches(" siu hong ") && siuHong.matches("兆康"))
        let tinShuiWai = stops.first { $0.id == 430 }!
        precondition(tinShuiWai.area == .tinShuiWai)
        precondition(tinShuiWai.matches("天水圍") && tinShuiWai.matches("天水围"))
        precondition(stops.first { $0.id == 600 }!.area == .yuenLong)
        precondition(stops.filter { $0.area == .tinShuiWai }.count == 17)
        precondition(stops.filter { $0.area == .yuenLong }.count == 8)
        precondition(stops.filter { $0.area == .tuenMun }.count == 43)
        precondition(stops.allSatisfy { !$0.routeIDs.isEmpty && $0.matches("") })
        precondition(!siuHong.matches("not a station"))
        print("PASS: 68 unique stops, all area groups, Siu Hong's seven routes and bilingual search.")
    }
}
