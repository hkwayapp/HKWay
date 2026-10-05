import Foundation

/// Explicit TD stop identifiers, not proximity or runtime name matching.
/// Checked against the local TD-derived Dataset/stops.json and feeder journeys
/// on 2026-08-31. Source: https://data.gov.hk/en-data/dataset/hk-td-tis_23-routes-fares-geojson
/// Includes stops whose published names explicitly identify the MTR station.
/// Recheck this allowlist when the underlying stop identifiers change.
enum FeederBusInterchange {
    static let tuenMaStationByStopID: [String: String] = [
        "9781": "TUM",  // Tuen Mun Station, Pui To Road
        "9830": "TUM",  // Tak Ching Court (MTR Tuen Mun Station)
        "12400": "TUM", // Tuen Mun Station Bus Terminus
        "13028": "TUM", // MTR Tuen Mun Station
        "13029": "TUM", // Tuen Mun Station
        "12388": "SIH", // Siu Hong Station (South)
        "12964": "SIH", // Siu Hong Station (North)
        "9898": "TIS",  // Tin Shui Wai Station, opposite boarding sides
        "9899": "TIS",
        "9908": "TIS",  // Tin Shui Wai Station Bus Terminus
        "12883": "YUL", // Yuen Long Station
        "9974": "LOP",  // Ping Cheong Path (MTR Long Ping Station)
        "9979": "LOP"   // Tai Kiu Tsuen (MTR Long Ping Station)
    ]

    static func hasTuenMaBadge(stopID: String, operatorIDs: [String]) -> Bool {
        operatorIDs.contains("LRTFeeder") && tuenMaStationByStopID[stopID] != nil
    }
}
