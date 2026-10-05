import Foundation

@main
struct AppAccessPolicyChecks {
    static func main() {
        let free = AppAccessPolicy(tier: .free)
        let full = AppAccessPolicy(tier: .full)

        precondition(AppAccessLimits.free.favoriteRoutes == 5)
        precondition(AppAccessLimits.free.favoriteBusStops == 5)
        precondition(AppAccessLimits.free.favoriteMTRStops == 5)
        precondition(AppAccessLimits.free.widgets == 1)

        for category in AppAccessCategory.allCases {
            let limit = AppAccessLimits.free.limit(for: category)!
            precondition(free.allowsAddition(to: category, existingCount: limit - 1, isAlreadySaved: false))
            precondition(!free.allowsAddition(to: category, existingCount: limit, isAlreadySaved: false))
            precondition(free.allowsAddition(to: category, existingCount: limit + 10, isAlreadySaved: true))
            precondition(full.allowsAddition(to: category, existingCount: 10_000, isAlreadySaved: false))
        }

        print("App access checks passed: separate Free limits, unlimited Full, existing data preserved")
    }
}
