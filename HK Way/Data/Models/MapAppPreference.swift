//
//  MapAppPreference.swift
//  HK Way
//

import Foundation

enum MapAppPreference: String, CaseIterable, Identifiable {
    static let storageKey = "preferredMapApp"

    case appleMaps
    case googleMaps

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMaps:
            "Apple Maps"
        case .googleMaps:
            "Google Maps"
        }
    }
}
