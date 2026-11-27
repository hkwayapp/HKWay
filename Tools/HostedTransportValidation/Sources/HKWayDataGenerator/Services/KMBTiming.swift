import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum KMBTiming {
    @TaskLocal static var counts: RequestCounts?

    final class RequestCounts: @unchecked Sendable {
        private let lock = NSLock()
        private var requests = 0
        private var attempts = 0

        func recordRequest() { lock.withLock { requests += 1 } }
        func recordAttempt() { lock.withLock { attempts += 1 } }

        func report(elapsed: TimeInterval) {
            lock.withLock {
                print("KMB/LWB total elapsed=\(elapsed)s HTTP requests=\(requests) attempts=\(attempts) retries=\(attempts - requests)")
            }
        }
    }

    static func download(_ url: URL, label: String) async throws -> (Data, URLResponse) {
        let start = ProcessInfo.processInfo.systemUptime
        defer { print("\(label) download elapsed=\(ProcessInfo.processInfo.systemUptime - start)s") }
        let response = try await DatasetHTTP.data(from: url)
        print("\(label) bytes=\(response.0.count)")
        return response
    }

    static func measure<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
        let start = ProcessInfo.processInfo.systemUptime
        defer { print("\(label) elapsed=\(ProcessInfo.processInfo.systemUptime - start)s") }
        return try body()
    }
}
