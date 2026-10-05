//
//  UniversalPlannerEndpoint.swift
//  HK Way
//

import Foundation
import CoreLocation

/// A selectable endpoint for the journey planner.  The stable identifier lets
/// the view combine imported operator stops with the separately maintained
/// MTR and ferry datasets without duplicating their source data.
enum UniversalPlannerEndpoint: Identifiable, Hashable {
    case transitStop(id: String, english: String, traditional: String, simplified: String, latitude: Double, longitude: Double)
    case mtrStation(id: String, english: String, traditional: String, simplified: String)
    case place(id: String, english: String, traditional: String, simplified: String, latitude: Double, longitude: Double, mtrStationID: String?)
    case ferryPier(id: String, title: String)
    case crossBoundary(CrossBoundaryCoachService)

    var id: String {
        switch self {
        case let .transitStop(id, _, _, _, _, _): "stop-\(id)"
        case let .mtrStation(id, _, _, _): "mtr-\(id)"
        case let .place(id, _, _, _, _, _, _): "place-\(id)"
        case let .ferryPier(id, _): "ferry-\(id)"
        case let .crossBoundary(service): "cross-boundary-\(service.id)"
        }
    }

    func title(language: TransitLanguage) -> String {
        switch self {
        case let .transitStop(_, english, traditional, simplified, _, _),
             let .mtrStation(_, english, traditional, simplified),
             let .place(_, english, traditional, simplified, _, _, _):
            switch language {
            case .english: english
            case .traditionalChinese: traditional
            case .simplifiedChinese: simplified
            }
        case let .ferryPier(_, title): title
        case let .crossBoundary(service): service.area(for: language)
        }
    }

    func subtitle(language: TransitLanguage) -> String {
        switch self {
        case .transitStop:
            switch language {
            case .english: "Bus stop"
            case .traditionalChinese: "巴士站"
            case .simplifiedChinese: "巴士站"
            }
        case .mtrStation:
            switch language {
            case .english: "MTR"
            case .traditionalChinese: "港鐵"
            case .simplifiedChinese: "港铁"
            }
        case .place:
            switch language {
            case .english: "Sightseeing destination"
            case .traditionalChinese: "觀光景點"
            case .simplifiedChinese: "观光景点"
            }
        case .ferryPier:
            switch language {
            case .english: "Ferry pier"
            case .traditionalChinese: "渡輪碼頭"
            case .simplifiedChinese: "渡轮码头"
            }
        case let .crossBoundary(service): service.operatorName(for: language)
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        if case let .transitStop(_, _, _, _, latitude, longitude) = self {
            return .init(latitude: latitude, longitude: longitude)
        }
        if case let .place(_, _, _, _, latitude, longitude, _) = self {
            return .init(latitude: latitude, longitude: longitude)
        }
        return nil
    }

    var islandDestination: IslandPlannerDestination? {
        guard case let .ferryPier(id, _) = self else { return nil }
        return switch id {
        case FerryPier.yungShueWan.id: IslandPlannerDestination.yungShueWan
        case FerryPier.sokKwuWan2.id: IslandPlannerDestination.sokKwuWan
        case FerryPier.cheungChau.id: IslandPlannerDestination.cheungChau
        case FerryPier.muiWo.id: IslandPlannerDestination.muiWo
        case FerryPier.pengChau.id: IslandPlannerDestination.pengChau
        default: nil
        }
    }

    var explicitMTRStationID: String? {
        if case let .mtrStation(id, _, _, _) = self { return id }
        return nil
    }

    var destinationMTRStationID: String? {
        if let explicitMTRStationID { return explicitMTRStationID }
        if case let .place(_, _, _, _, _, _, stationID) = self { return stationID }
        let english = title(language: .english).lowercased()
        if english.contains("disneyland") { return "DIS" }
        if english.contains("ocean park") { return "OCP" }
        return nil
    }


    var originMTRStationID: String? {
        destinationMTRStationID
    }
}

@MainActor
extension UniversalPlannerEndpoint {
    static func stop(_ stop: StopEntity) -> Self {
        .transitStop(
            id: stop.id,
            english: stop.displayNameEnglish,
            traditional: stop.displayNameTraditional,
            simplified: stop.displayNameSimplified,
            latitude: stop.latitude,
            longitude: stop.longitude
        )
    }

    static func station(_ station: MTRStation) -> Self {
        .mtrStation(
            id: station.id,
            english: station.english,
            traditional: station.traditional,
            simplified: station.simplified
        )
    }

    static func pier(_ pier: FerryPier) -> Self {
        .ferryPier(id: pier.id, title: pier.title)
    }
}
