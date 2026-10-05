import Foundation

enum AppAccessTier: String, Codable, Sendable {
    case free
    case full
}

enum AppAccessCategory: String, CaseIterable, Sendable {
    case favoriteRoutes
    case favoriteBusStops
    case favoriteMTRStops
    case favoriteLightRailStops
    case widgets
}

struct AppAccessLimits: Equatable, Sendable {
    let favoriteRoutes: Int?
    let favoriteBusStops: Int?
    let favoriteMTRStops: Int?
    let favoriteLightRailStops: Int?
    let widgets: Int?

    // All features are available without a purchase. Legacy tier values remain
    // decodable for existing installations, but no longer affect limits.
    static let free = full

    static let full = Self(
        favoriteRoutes: nil,
        favoriteBusStops: nil,
        favoriteMTRStops: nil,
        favoriteLightRailStops: nil,
        widgets: nil
    )

    func limit(for category: AppAccessCategory) -> Int? {
        switch category {
        case .favoriteRoutes: favoriteRoutes
        case .favoriteBusStops: favoriteBusStops
        case .favoriteMTRStops: favoriteMTRStops
        case .favoriteLightRailStops: favoriteLightRailStops
        case .widgets: widgets
        }
    }
}

struct AppAccessPolicy: Sendable {
    let tier: AppAccessTier

    var limits: AppAccessLimits {
        .full
    }

    func allowsAddition(
        to category: AppAccessCategory,
        existingCount: Int,
        isAlreadySaved: Bool
    ) -> Bool {
        // Existing records always remain usable and removable. This prevents a
        // Free-tier transition from silently deleting or trapping user data.
        if isAlreadySaved { return true }
        guard let limit = limits.limit(for: category) else { return true }
        return existingCount < limit
    }
}
