import Foundation

enum TVBusOperator: String, CaseIterable, Identifiable {
    case kmb = "KMB"
    case longWinBus = "LWB"
    case citybus = "CTB"
    case newLantaoBus = "NLB"
    case greenMinibus = "GMB"
    case mtrBus = "LRTFeeder"
    case maWanBus = "PI"
    case discoveryBayBus = "DB"
    case crossBoundaryCoach = "XB"

    var id: String { rawValue }

    func name(_ language: TVLanguage) -> String {
        switch (self, language) {
        case (.kmb, .english): "KMB"
        case (.kmb, .traditionalChinese): "九巴"
        case (.kmb, .simplifiedChinese): "九巴"
        case (.longWinBus, .english): "Long Win Bus"
        case (.longWinBus, .traditionalChinese): "龍運巴士"
        case (.longWinBus, .simplifiedChinese): "龙运巴士"
        case (.citybus, .english): "Citybus"
        case (.citybus, .traditionalChinese): "城巴"
        case (.citybus, .simplifiedChinese): "城巴"
        case (.newLantaoBus, .english): "New Lantao Bus"
        case (.newLantaoBus, .traditionalChinese): "新大嶼山巴士"
        case (.newLantaoBus, .simplifiedChinese): "新大屿山巴士"
        case (.greenMinibus, .english): "Green Minibus"
        case (.greenMinibus, .traditionalChinese): "專線小巴"
        case (.greenMinibus, .simplifiedChinese): "专线小巴"
        case (.mtrBus, .english): "MTR Bus"
        case (.mtrBus, .traditionalChinese): "港鐵巴士"
        case (.mtrBus, .simplifiedChinese): "港铁巴士"
        case (.maWanBus, .english): "Ma Wan Bus"
        case (.maWanBus, .traditionalChinese): "馬灣巴士"
        case (.maWanBus, .simplifiedChinese): "马湾巴士"
        case (.discoveryBayBus, .english): "Discovery Bay Bus"
        case (.discoveryBayBus, .traditionalChinese): "愉景灣巴士"
        case (.discoveryBayBus, .simplifiedChinese): "愉景湾巴士"
        case (.crossBoundaryCoach, .english): "Cross-boundary Coach"
        case (.crossBoundaryCoach, .traditionalChinese): "過境巴士"
        case (.crossBoundaryCoach, .simplifiedChinese): "过境巴士"
        }
    }
}

enum TVOperatorSelection {
    static let storageKey = "tvSelectedOperatorIDs"

    static func ids(from value: String) -> Set<String> {
        Set(value.split(separator: "\n").map(String.init))
    }

    static func value(from ids: Set<String>) -> String {
        ids.sorted().joined(separator: "\n")
    }
}

extension TVLanguage {
    func text(_ english: String, _ traditional: String, _ simplified: String) -> String {
        switch self {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }
}
