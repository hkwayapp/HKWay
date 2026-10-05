import Foundation

struct CrossBoundaryCoachService: Identifiable, Hashable {
    let id: String
    let area: [TransitLanguage: String]
    let boardingPoint: [TransitLanguage: String]
    let operatorName: [TransitLanguage: String]
    let officialURL: URL

    func area(for language: TransitLanguage) -> String { area[language] ?? area[.english] ?? id }
    func boardingPoint(for language: TransitLanguage) -> String { boardingPoint[language] ?? boardingPoint[.english] ?? "" }
    func operatorName(for language: TransitLanguage) -> String { operatorName[language] ?? operatorName[.english] ?? "" }

    static let huanggang: [Self] = {
        let base = "https://www.td.gov.hk/en/transport_in_hong_kong/land_based_cross_boundary_transport/access_to_lok_ma_chau_control_point"
        func text(_ en: String, _ tc: String, _ sc: String) -> [TransitLanguage: String] {
            [.english: en, .traditionalChinese: tc, .simplifiedChinese: sc]
        }
        return [
            .init(id: "mong-kok", area: text("Mong Kok ↔ Huanggang Port", "旺角 ↔ 皇崗口岸", "旺角 ↔ 皇岗口岸"), boardingPoint: text("Arran Street, outside Golden Plaza", "鴉蘭街（金都商場外）", "鸦兰街（金都商场外）"), operatorName: text("All China Express (Mong Kok)", "全日通（旺角）", "全日通（旺角）"), officialURL: URL(string: "\(base)/mong_kok_route/index.html")!),
            .init(id: "yau-tsim", area: text("Yau Tsim ↔ Huanggang Port", "油尖 ↔ 皇崗口岸", "油尖 ↔ 皇岗口岸"), boardingPoint: text("Austin Road Cross Boundary Coach Terminus", "柯士甸道跨境巴士總站", "柯士甸道跨境巴士总站"), operatorName: text("Express Cross-Border Coach Management (Yau Tsim)", "跨境全日通（油尖）", "跨境全日通（油尖）"), officialURL: URL(string: "\(base)/yau_tsim_route/index.html")!),
            .init(id: "kwun-tong", area: text("Kwun Tong ↔ Huanggang Port", "觀塘 ↔ 皇崗口岸", "观塘 ↔ 皇岗口岸"), boardingPoint: text("Lam Tin Station Public Transport Interchange / apm", "藍田站公共運輸交匯處／apm", "蓝田站公共运输交汇处／apm"), operatorName: text("Express Cross-Border Coach Management (Kwun Tong)", "跨境全日通（觀塘）", "跨境全日通（观塘）"), officialURL: URL(string: "\(base)/kwun_tong_route/index.html")!),
            .init(id: "wan-chai", area: text("Wan Chai ↔ Huanggang Port", "灣仔 ↔ 皇崗口岸", "湾仔 ↔ 皇岗口岸"), boardingPoint: text("Exhibition Centre Station Public Transport Interchange", "會展站公共運輸交匯處", "会展站公共运输交汇处"), operatorName: text("All China Express (Wan Chai)", "全日通（灣仔）", "全日通（湾仔）"), officialURL: URL(string: "\(base)/wan_chai_route/index.html")!),
            .init(id: "tsuen-wan", area: text("Tsuen Wan ↔ Huanggang Port", "荃灣 ↔ 皇崗口岸", "荃湾 ↔ 皇岗口岸"), boardingPoint: text("Discovery Park / Nan Fung Centre for overnight services", "愉景新城／通宵服務於南豐中心", "愉景新城／通宵服务于南丰中心"), operatorName: text("China-Hong Kong Express", "中港直通快線", "中港直通快线"), officialURL: URL(string: "\(base)/tsuen_wan_route/index.html")!)
        ]
    }()
}
