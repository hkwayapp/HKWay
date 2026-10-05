import Foundation

@main
struct FerryCatalogueChecks {
    static func main() throws {
        let routes = FerryCatalogue.routes
        let groupedPiers = FerryPierRegion.allCases.flatMap(\.piers)
        precondition(groupedPiers.count == FerryPier.allCases.count)
        precondition(Set(groupedPiers) == Set(FerryPier.allCases))
        precondition(FerryPierRegion.urban.piers.count == 9)
        precondition(FerryPierRegion.islands.piers.count == 6)
        precondition(Set(FerryPierRegion.allCases.flatMap(\.locations)) == Set(FerryLocation.allCases))
        precondition(Set(FerryPierRegion.urban.locations) == [.central, .tsimShaTsui, .wanChai, .tsuenWan])
        precondition(Set(FerryPierRegion.islands.locations) == [.cheungChau, .muiWo, .pengChau, .yungShueWan, .sokKwuWan, .maWan])
        precondition(FerryPier.tsimShaTsui.region == .urban)
        precondition(FerryPier.muiWo.region == .islands)
        precondition(Set(routes.map(\.id)) == ["7005", "7006", "7007", "7008", "7009", "7017", "7018", "7030", "7031"])
        precondition(routes.count == 9)
        precondition(FerryCatalogue.routes(at: .central5).map(\.id) == ["7005"])
        precondition(FerryCatalogue.routes(at: .central6East).map(\.id) == ["7006"])
        precondition(FerryCatalogue.routes(at: .central7).map(\.id) == ["7030"])
        precondition(FerryCatalogue.routes(at: .tsimShaTsui).count == 2)
        precondition(FerryCatalogue.routes(in: .central).count == 7)
        precondition(FerryCatalogue.routes(at: .central6West).map(\.id) == ["7007"])
        precondition(Set(FerryCatalogue.routes(at: .central4).map(\.id)) == ["7008", "7009"])
        precondition(FerryCatalogue.routes(at: .pengChau).map(\.id) == ["7007"])
        precondition(FerryCatalogue.routes(at: .yungShueWan).map(\.id) == ["7009"])
        precondition(FerryCatalogue.routes(at: .sokKwuWan2).map(\.id) == ["7008"])
        precondition(FerryCatalogue.routes(in: .wanChai).map(\.id) == ["7031"])
        precondition(Set(FerryCatalogue.routes(in: .maWan).map(\.id)) == ["7017", "7018"])
        for operatorID in FerryOperator.allCases {
            let expected = operatorID == .hkkf ? 3 : 2
            precondition(FerryCatalogue.routes(by: operatorID).count == expected)
        }
        for pier in FerryPier.allCases {
            precondition(!FerryCatalogue.routes(at: pier).isEmpty)
        }
        for route in routes {
            precondition(route.origin != route.destination)
            precondition(route.initialDeparture() == route.origin)
            for pier in route.piers {
                precondition(route.initialDeparture(pier: pier) == pier)
                precondition(route.initialDeparture(location: pier.location) == pier)
                let arrival = route.arrival(from: pier)
                precondition(arrival != pier)
                precondition(route.arrival(from: arrival) == pier)
            }
            let unrelated = FerryPier.allCases.first { !route.piers.contains($0) }!
            precondition(route.initialDeparture(pier: unrelated) == route.origin)
            // Both endpoint selections must find the same route (including the return pier).
            for pier in route.piers {
                precondition(FerryCatalogue.routes(at: pier).contains { $0.id == route.id })
            }
            for path in ["en", "tc", "sc"] {
                let url = route.officialURL(languagePath: path)
                precondition(url.scheme == "https" && url.host == "www.td.gov.hk")
                precondition(url.path.hasPrefix("/\(path)/"))
                precondition(url.fragment == route.sourceAnchor)
            }
        }
        let file = CommandLine.arguments[1]
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        let records = try JSONDecoder().decode([[String: String]].self, from: data)
        for route in routes {
            let record = records.first { $0["ROUTE_ID"] == route.id }!
            precondition(record["COMPANY_CODE"] == "FERRY")
            precondition(record["HYPERLINK_E"] == route.officialURL(languagePath: "en").absoluteString)
            let endpoints = Set([record["LOC_START_NAMEE"]!, record["LOC_END_NAMEE"]!])
            precondition(endpoints == Set(route.piers.map { $0.location.title }))
            if let minutes = route.referenceMinutes {
                precondition(minutes == Int(record["JOURNEY_TIME"]!))
            }
        }
        // Do not expose ambiguous/obsolete island-route durations as a single estimate.
        precondition(routes.filter { $0.operatorID == .sun }.allSatisfy { $0.referenceMinutes == nil })
        print("Ferry catalogue: source IDs, endpoints, grouping, return-pier lookup and official URLs passed.")
    }
}
