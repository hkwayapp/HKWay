import Foundation

@main
enum CrossBoundaryCoachChecks {
    static func main() {
        let services = CrossBoundaryCoachService.huanggang
        precondition(services.count == 5)
        precondition(Set(services.map(\.id)).count == services.count)
        precondition(services.allSatisfy { $0.officialURL.host == "www.td.gov.hk" })
        precondition(services.allSatisfy { $0.officialURL.path.contains("access_to_lok_ma_chau_control_point") })
        precondition(services.first { $0.id == "mong-kok" }?.area(for: .traditionalChinese).contains("皇崗") == true)
        precondition(services.first { $0.id == "kwun-tong" }?.boardingPoint(for: .simplifiedChinese).contains("蓝田") == true)
        precondition(services.first { $0.id == "tsuen-wan" }?.operatorName(for: .english) == "China-Hong Kong Express")
        print("Cross-boundary coach checks passed: 5 localized TD short-haul corridors")
    }
}
