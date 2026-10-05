import Foundation

enum BuddhaBusConnection {
    // Regular services verified at https://www.nlb.com.hk/route?q=2 (2026-08-31).
    // TD Ngong Ping terminus ID from the existing open-data stop catalogue.
    // Deliberately excludes demand-only S variants and special-service 1R.
    static func matches(number: String, operatorIDs: [String], endpointIDs: [String]) -> Bool {
        operatorIDs.contains("NLB") && ["2", "21", "23"].contains(number)
            && endpointIDs.contains("11013")
    }
}
