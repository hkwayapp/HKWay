enum NearbySearchRadius: Int, CaseIterable, Identifiable {
    case close = 100
    case medium = 200
    case wide = 400

    static let storageKey = "nearbySearchRadiusMeters"
    var id: Int { rawValue }
    var title: String { "\(rawValue) m" }

    init(storedValue: Int) {
        self = Self(rawValue: storedValue) ?? .close
    }
}
