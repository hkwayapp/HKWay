import Foundation

// Small, offline starter catalogue. Source IDs refer to TD's ROUTE_FERRY.xml.
// See Documentation/FerrySources.md for provenance and deliberately omitted values.
enum FerryOperator: String, CaseIterable, Identifiable {
    case star, sun, hkkf, parkIsland
    var id: String { rawValue }
    var title: String {
        switch self {
        case .star: "Star Ferry"
        case .sun: "Sun Ferry"
        case .hkkf: "Hong Kong & Kowloon Ferry"
        case .parkIsland: "Park Island Transport"
        }
    }
}

enum FerryLocation: String, CaseIterable, Identifiable {
    case central, tsimShaTsui, wanChai, cheungChau, muiWo
    case pengChau, yungShueWan, sokKwuWan, maWan, tsuenWan
    var id: String { rawValue }
    var title: String {
        switch self {
        case .central: "Central"
        case .tsimShaTsui: "Tsim Sha Tsui"
        case .wanChai: "Wan Chai"
        case .cheungChau: "Cheung Chau"
        case .muiWo: "Mui Wo"
        case .pengChau: "Peng Chau"
        case .yungShueWan: "Yung Shue Wan"
        case .sokKwuWan: "Sok Kwu Wan"
        case .maWan: "Ma Wan"
        case .tsuenWan: "Tsuen Wan"
        }
    }
}

enum FerryPierRegion: String, CaseIterable, Identifiable {
    case urban = "Hong Kong & Kowloon"
    case islands = "Outlying Islands"
    var id: String { rawValue }
    var piers: [FerryPier] { FerryPier.allCases.filter { $0.region == self } }
    var locations: [FerryLocation] {
        FerryLocation.allCases.filter { location in
            piers.contains { $0.location == location }
        }
    }
}

enum FerryPier: String, CaseIterable, Identifiable {
    case central2, central4, central5, central6East, central6West, central7
    case tsimShaTsui, wanChai, cheungChau, muiWo, pengChau, yungShueWan, sokKwuWan2
    case maWan, tsuenWan
    var id: String { rawValue }
    var region: FerryPierRegion {
        switch location {
        case .central, .tsimShaTsui, .wanChai, .tsuenWan: .urban
        case .cheungChau, .muiWo, .pengChau, .yungShueWan, .sokKwuWan, .maWan: .islands
        }
    }
    var title: String {
        switch self {
        case .central2: "Central Pier 2"
        case .central4: "Central Pier 4"
        case .central5: "Central Pier 5"
        case .central6East: "Central Pier 6 (Eastern Berth)"
        case .central6West: "Central Pier 6 (Western Berth)"
        case .central7: "Central Pier 7"
        case .tsimShaTsui: "Tsim Sha Tsui Star Ferry Pier"
        case .wanChai: "Wan Chai Ferry Pier"
        case .cheungChau: "Cheung Chau Ferry Pier"
        case .muiWo: "Mui Wo Ferry Pier"
        case .pengChau: "Peng Chau Ferry Pier"
        case .yungShueWan: "Yung Shue Wan Ferry Pier"
        case .sokKwuWan2: "Sok Kwu Wan Pier 2"
        case .maWan: "Park Island Ferry Pier"
        case .tsuenWan: "Tsuen Wan Ferry Pier"
        }
    }
    var location: FerryLocation {
        switch self {
        case .central2, .central4, .central5, .central6East, .central6West, .central7: .central
        case .tsimShaTsui: .tsimShaTsui
        case .wanChai: .wanChai
        case .cheungChau: .cheungChau
        case .muiWo: .muiWo
        case .pengChau: .pengChau
        case .yungShueWan: .yungShueWan
        case .sokKwuWan2: .sokKwuWan
        case .maWan: .maWan
        case .tsuenWan: .tsuenWan
        }
    }
}

struct FerryConnection: Identifiable {
    let id: String
    let operatorID: FerryOperator
    let origin: FerryPier
    let destination: FerryPier
    let referenceMinutes: Int?
    let sourceAnchor: String

    var piers: [FerryPier] { [origin, destination] }

    func initialDeparture(pier: FerryPier? = nil, location: FerryLocation? = nil) -> FerryPier {
        if let pier, piers.contains(pier) { return pier }
        if let location, let match = piers.first(where: { $0.location == location }) { return match }
        return origin
    }

    func arrival(from departure: FerryPier) -> FerryPier {
        departure == destination ? origin : destination
    }

    func officialURL(languagePath: String) -> URL {
        let path = ["en", "tc", "sc"].contains(languagePath) ? languagePath : "en"
        return URL(string: "https://www.td.gov.hk/\(path)/transport_in_hong_kong/public_transport/ferries/service_details/index.html#\(sourceAnchor)")!
    }
}

enum FerryCatalogue {
    static let routes: [FerryConnection] = [
        .init(id: "7030", operatorID: .star, origin: .central7, destination: .tsimShaTsui,
              referenceMinutes: 9, sourceAnchor: "i04"),
        .init(id: "7031", operatorID: .star, origin: .wanChai, destination: .tsimShaTsui,
              referenceMinutes: 8, sourceAnchor: "i05"),
        .init(id: "7005", operatorID: .sun, origin: .central5, destination: .cheungChau,
              referenceMinutes: nil, sourceAnchor: "o01"),
        .init(id: "7006", operatorID: .sun, origin: .central6East, destination: .muiWo,
              referenceMinutes: nil, sourceAnchor: "o02"),
        .init(id: "7007", operatorID: .hkkf, origin: .central6West, destination: .pengChau,
              referenceMinutes: nil, sourceAnchor: "o03"),
        .init(id: "7009", operatorID: .hkkf, origin: .central4, destination: .yungShueWan,
              referenceMinutes: 27, sourceAnchor: "o04"),
        .init(id: "7008", operatorID: .hkkf, origin: .central4, destination: .sokKwuWan2,
              referenceMinutes: nil, sourceAnchor: "o05"),
        .init(id: "7017", operatorID: .parkIsland, origin: .maWan, destination: .central2,
              referenceMinutes: 22, sourceAnchor: "o16"),
        .init(id: "7018", operatorID: .parkIsland, origin: .maWan, destination: .tsuenWan,
              referenceMinutes: 12, sourceAnchor: "o17")
    ]

    static func routes(at pier: FerryPier) -> [FerryConnection] {
        routes.filter { $0.piers.contains(pier) }
    }
    static func routes(in location: FerryLocation) -> [FerryConnection] {
        routes.filter { $0.piers.contains { $0.location == location } }
    }
    static func routes(by operatorID: FerryOperator) -> [FerryConnection] {
        routes.filter { $0.operatorID == operatorID }
    }
}
