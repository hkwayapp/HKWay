import Foundation

@main
struct MaWanResidentBusCatalogueChecks {
    static func main() {
        let routes = MaWanResidentBusCatalogue.routes
        precondition(routes.map(\.number) == ["NR330", "NR331", "NR332", "NR334", "NR338", "NR338S"])
        precondition(Set(routes.map(\.id)).count == routes.count)
        precondition(routes.allSatisfy { $0.officialURL.scheme == "https" })
        precondition(routes.allSatisfy { $0.officialURL.host == "www.td.gov.hk" })
        precondition(routes.allSatisfy { $0.officialURL.path.hasSuffix($0.documentFileName) })
        print("Ma Wan resident-bus catalogue checks passed.")
    }
}
