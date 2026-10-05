import Foundation
import SwiftUI

enum KaiTakVenue: String, CaseIterable, Identifiable {
    case stadium
    case arena

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .stadium: "Kai Tak Stadium"
        case .arena: "Kai Tak Arena"
        }
    }
}

enum KaiTakServicePhase {
    case arrival
    case departure
}

struct KaiTakEventService: Identifiable {
    let id: String
    let phase: KaiTakServicePhase
    let route: String
    let boardingArea: String
    let operatorName: String
}

struct KaiTakEventArrangement: Identifiable {
    let id: String
    let venue: KaiTakVenue
    let title: String
    let startDate: Date
    let endDate: Date
    let sourceURL: URL
    let services: [KaiTakEventService]

    static func current(
        from arrangements: [Self],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Self] {
        let today = calendar.startOfDay(for: now)
        return arrangements
            .filter { calendar.startOfDay(for: $0.endDate) >= today }
            .sorted { $0.startDate < $1.startDate }
    }
}

struct KaiTakSpecialRoute: Identifiable {
    enum Operator: String {
        case kmb
        case citybus
        case kmbAndCitybus

        var englishName: String {
            switch self {
            case .kmb: "KMB"
            case .citybus: "Citybus"
            case .kmbAndCitybus: "KMB / Citybus"
            }
        }

        func displayName(for language: TransitLanguage) -> String {
            switch language {
            case .english:
                englishName
            case .traditionalChinese, .simplifiedChinese:
                switch self {
                case .kmb: "九巴"
                case .citybus: "城巴"
                case .kmbAndCitybus: "九巴 / 城巴"
                }
            }
        }
    }

    let number: String
    let destinationEnglish: String
    let destinationTraditional: String
    let destinationSimplified: String
    let routeOperator: Operator

    var id: String { "\(routeOperator.rawValue)-\(number)" }

    func destination(for language: TransitLanguage) -> String {
        switch language {
        case .english: destinationEnglish
        case .traditionalChinese: destinationTraditional
        case .simplifiedChinese: destinationSimplified
        }
    }

    static let catalogue: [Self] = {
        return [
            .init(number: "SP1", destinationEnglish: "Hang Hau (North)", destinationTraditional: "坑口（北）", destinationSimplified: "坑口（北）", routeOperator: .kmb),
            .init(number: "SP2", destinationEnglish: "Prince Edward · Mong Kok", destinationTraditional: "太子 · 旺角", destinationSimplified: "太子 · 旺角", routeOperator: .citybus),
            .init(number: "SP2A", destinationEnglish: "Tsim Sha Tsui", destinationTraditional: "尖沙咀", destinationSimplified: "尖沙咀", routeOperator: .citybus),
            .init(number: "SP3", destinationEnglish: "Ching Fu Court", destinationTraditional: "青富苑", destinationSimplified: "青富苑", routeOperator: .kmb),
            .init(number: "SP5A", destinationEnglish: "Tuen Mun Pier Head", destinationTraditional: "屯門碼頭", destinationSimplified: "屯门码头", routeOperator: .kmb),
            .init(number: "SP5B", destinationEnglish: "Tuen Mun (Ching Tin · Wo Tin)", destinationTraditional: "屯門（菁田 · 和田）", destinationSimplified: "屯门（菁田 · 和田）", routeOperator: .citybus),
            .init(number: "SP6", destinationEnglish: "Tin Heng Estate", destinationTraditional: "天恆邨", destinationSimplified: "天恒邨", routeOperator: .kmb),
            .init(number: "SP7", destinationEnglish: "Sheung Shui via Pak Shek Kok, Tai Po and Fanling", destinationTraditional: "上水（經白石角、大埔及粉嶺）", destinationSimplified: "上水（经白石角、大埔及粉岭）", routeOperator: .kmb),
            .init(number: "SP9", destinationEnglish: "LOHAS Park", destinationTraditional: "日出康城", destinationSimplified: "日出康城", routeOperator: .citybus),
            .init(number: "SP10", destinationEnglish: "Central (Macao Ferry)", destinationTraditional: "中環（港澳碼頭）", destinationSimplified: "中环（港澳码头）", routeOperator: .kmbAndCitybus),
            .init(number: "SP11", destinationEnglish: "Siu Sai Wan (Island Resort)", destinationTraditional: "小西灣（藍灣半島）", destinationSimplified: "小西湾（蓝湾半岛）", routeOperator: .citybus),
            .init(number: "SP12", destinationEnglish: "Lok Ma Chau (San Tin)", destinationTraditional: "落馬洲（新田）", destinationSimplified: "落马洲（新田）", routeOperator: .kmbAndCitybus)
        ]
    }()
}
