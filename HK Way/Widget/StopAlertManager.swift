import ActivityKit

nonisolated struct StopAlertAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var status: String
        var detail: String
        var nextStop: String
        var remainingStops: Int
        var totalStops: Int
    }

    var routeNumber: String
    var targetStop: String
}
