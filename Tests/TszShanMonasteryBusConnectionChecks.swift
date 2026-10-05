import Foundation

@main
struct TszShanMonasteryBusConnectionChecks {
    static func main() {
        precondition(TszShanMonasteryBusConnection.kind(number: "20T", operatorIDs: ["GMB"]) == .directLimited)

        for number in ["20B", "20C"] {
            precondition(TszShanMonasteryBusConnection.kind(number: number, operatorIDs: ["GMB"]) == .nearby)
            precondition(TszShanMonasteryBusConnection.kind(number: number, operatorIDs: ["KMB"]) == nil)
        }

        for number in ["75K", "275R"] {
            precondition(TszShanMonasteryBusConnection.kind(number: number, operatorIDs: ["KMB"]) == .nearby)
            precondition(TszShanMonasteryBusConnection.kind(number: number, operatorIDs: ["GMB"]) == nil)
        }

        for number in ["20", "20A", "75", "275", "NR532", ""] {
            precondition(TszShanMonasteryBusConnection.kind(number: number, operatorIDs: ["GMB", "KMB"]) == nil)
        }

        print("Tsz Shan Monastery connection checks passed")
    }
}
