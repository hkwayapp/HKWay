import Foundation

enum TszShanMonasteryBusConnection {
    enum Kind {
        case directLimited
        case nearby
    }

    static func kind(number: String, operatorIDs: [String]) -> Kind? {
        let normalized = number.uppercased()

        if normalized == "20T", operatorIDs.contains("GMB") {
            return .directLimited
        }

        if ["20B", "20C"].contains(normalized), operatorIDs.contains("GMB") {
            return .nearby
        }

        if ["75K", "275R"].contains(normalized), operatorIDs.contains("KMB") {
            return .nearby
        }

        return nil
    }
}
