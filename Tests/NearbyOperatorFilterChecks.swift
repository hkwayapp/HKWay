import Foundation

@main enum NearbyOperatorFilterChecks {
    static func main() {
        let preferences: Set<String> = ["CTB"]
        var filter = NearbyOperatorFilter.preferences
        precondition(!filter.includes(["KMB"], preferences: preferences))
        precondition(filter.includes(["KMB", "CTB"], preferences: preferences))
        filter = .all
        precondition(filter.includes(["KMB"], preferences: preferences))
        precondition(filter.includes([], preferences: preferences))
        filter.toggle("KMB")
        precondition(filter.isSelected("KMB"))
        precondition(filter.includes(["KMB"], preferences: preferences))
        precondition(!filter.includes(["CTB"], preferences: preferences))
        filter.toggle("CTB")
        precondition(filter.includes(["CTB"], preferences: preferences))
        filter.toggle("KMB")
        filter.toggle("CTB")
        precondition(filter == .all)
        filter = .preferences
        precondition(!filter.includes(["KMB"], preferences: preferences))
        precondition(filter.includes(["KMB"], preferences: []))
        print("Nearby operator checks passed: All overrides preferences, explicit selection, joint operators and preference restoration.")
    }
}
