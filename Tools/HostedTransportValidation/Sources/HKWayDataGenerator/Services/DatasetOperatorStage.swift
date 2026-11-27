import Foundation

enum DatasetOperatorStage {
    static func run<Value>(
        _ name: String, operation: () async throws -> Value
    ) async -> (value: Value?, complete: Bool) {
        let start = ProcessInfo.processInfo.systemUptime
        let previousIssues = await DatasetHTTP.issueCount()
        defer { print("\(name) elapsed: \(ProcessInfo.processInfo.systemUptime - start)s") }
        do {
            let value = try await operation()
            let complete = await DatasetHTTP.issueCount() == previousIssues
            print("\(name): \(complete ? "refreshed in staging" : "partial source result; staging only")")
            return (value, complete)
        } catch {
            await DatasetHTTP.recordFailure(name, error)
            return (nil, false)
        }
    }

    static func requirePublishable(_ operatorResults: [Bool]) throws {
        guard operatorResults.allSatisfy({ $0 }) else {
            let result = operatorResults.contains(true) ? "PARTIAL SUCCESS" : "COMPLETE FAILURE"
            print("Dataset \(result): retained the complete previous published snapshot and its original manifest.")
            print("Route-only or CTB-only replacement is unsafe with shared route/stop tables and a single freshness timestamp.")
            throw PublicationBlocked()
        }
        print("Operator fetches: FULL SUCCESS; combined snapshot still requires validation.")
    }

    struct PublicationBlocked: Error {}
}
