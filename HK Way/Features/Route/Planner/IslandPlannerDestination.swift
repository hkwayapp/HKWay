//
//  IslandPlannerDestination.swift
//  HK Way
//

import CoreLocation
import Foundation

enum IslandPlannerDestination: String, CaseIterable, Identifiable {
    case yungShueWan
    case sokKwuWan
    case cheungChau
    case muiWo
    case pengChau

    var id: String { rawValue }

    var ferryPierQuery: String {
        switch self {
        case .yungShueWan, .sokKwuWan: "Central Pier 4, Hong Kong"
        case .cheungChau: "Central Pier 5, Hong Kong"
        case .muiWo: "Central Pier 6, Hong Kong"
        case .pengChau: "Central Pier 6, Hong Kong"
        }
    }

    var destinationQuery: String {
        switch self {
        case .yungShueWan: "Yung Shue Wan Ferry Pier, Hong Kong"
        case .sokKwuWan: "Sok Kwu Wan Pier 2, Hong Kong"
        case .cheungChau: "Cheung Chau Ferry Pier, Hong Kong"
        case .muiWo: "Mui Wo Ferry Pier, Hong Kong"
        case .pengChau: "Peng Chau Ferry Pier, Hong Kong"
        }
    }

    var ferryPierCoordinate: CLLocationCoordinate2D {
        switch self {
        case .yungShueWan, .sokKwuWan:
            CLLocationCoordinate2D(latitude: 22.28872, longitude: 114.15962)
        case .cheungChau:
            CLLocationCoordinate2D(latitude: 22.28845, longitude: 114.15875)
        case .muiWo:
            CLLocationCoordinate2D(latitude: 22.28829, longitude: 114.15783)
        case .pengChau:
            CLLocationCoordinate2D(latitude: 22.28815, longitude: 114.15735)
        }
    }

    func title(language: TransitLanguage) -> String {
        switch (self, language) {
        case (.yungShueWan, .english): "Yung Shue Wan, Lamma Island"
        case (.yungShueWan, .traditionalChinese): "南丫島榕樹灣"
        case (.yungShueWan, .simplifiedChinese): "南丫岛榕树湾"
        case (.sokKwuWan, .english): "Sok Kwu Wan, Lamma Island"
        case (.sokKwuWan, .traditionalChinese): "南丫島索罟灣"
        case (.sokKwuWan, .simplifiedChinese): "南丫岛索罟湾"
        case (.cheungChau, .english): "Cheung Chau"
        case (.cheungChau, .traditionalChinese): "長洲"
        case (.cheungChau, .simplifiedChinese): "长洲"
        case (.muiWo, .english): "Mui Wo"
        case (.muiWo, .traditionalChinese): "梅窩"
        case (.muiWo, .simplifiedChinese): "梅窝"
        case (.pengChau, .english): "Peng Chau"
        case (.pengChau, .traditionalChinese): "坪洲"
        case (.pengChau, .simplifiedChinese): "坪洲"
        }
    }
}
