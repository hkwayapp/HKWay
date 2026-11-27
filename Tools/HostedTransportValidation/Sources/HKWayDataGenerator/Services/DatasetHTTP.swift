import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum DatasetHTTP {
    @TaskLocal static var replay: OfflineResponseArchive?
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private static let failures = FailureLog()

    static func data(from url: URL, trackFailure: Bool = true, retry: Bool = true) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url), trackFailure: trackFailure, retry: retry)
    }

    static func data(for request: URLRequest, trackFailure: Bool = true, retry: Bool = true) async throws -> (Data, URLResponse) {
        if let replay {
            do {
                guard let url = request.url, request.httpMethod == "GET" else { throw URLError(.unsupportedURL) }
                return try replay.response(for: url)
            } catch {
                if trackFailure { await recordFailure(request.url?.absoluteString ?? "offline source", error) }
                throw error
            }
        }
        var request = request
        request.timeoutInterval = min(request.timeoutInterval, 20)
        let source = request.url?.absoluteString ?? "unknown URL"
        let start = ProcessInfo.processInfo.systemUptime
        defer { print("HTTP \(source) elapsed=\(ProcessInfo.processInfo.systemUptime - start)s") }

        KMBTiming.counts?.recordRequest()
        let maximumAttempts = retry ? 3 : 1
        for attempt in 1...maximumAttempts {
            KMBTiming.counts?.recordAttempt()
            do {
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200..<300).contains(response.statusCode) else {
                    throw HTTPStatus(code: response.statusCode)
                }
                guard !data.isEmpty else { throw URLError(.zeroByteResource) }
                return (data, response)
            } catch {
                try Task.checkCancellation()
                print("HTTP \(source) attempt \(attempt): \(error)")
                guard attempt < maximumAttempts, shouldRetry(error) else {
                    if trackFailure { await recordFailure(source, error) }
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }
        preconditionFailure("The last failed request must throw")
    }

    static func recordFailure(_ source: String, _ error: Error) async {
        print("Dataset source failure: \(source): \(error)")
        await failures.add(source)
    }

    static func requireCompleteSources() async throws {
        let sources = await failures.sources.sorted()
        guard sources.isEmpty else { throw IncompleteSources(sources: sources) }
    }

    static func recordRetention(_ source: String) async {
        await failures.add(source)
    }

    static func issueCount() async -> Int {
        await failures.sources.count
    }

    private static func shouldRetry(_ error: Error) -> Bool {
        if let status = error as? HTTPStatus {
            return [408, 429].contains(status.code) || (500..<600).contains(status.code)
        }
        guard let error = error as? URLError else { return false }
        return [.timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                .networkConnectionLost, .notConnectedToInternet, .zeroByteResource].contains(error.code)
    }

    private struct HTTPStatus: Error { let code: Int }

    private struct IncompleteSources: LocalizedError {
        let sources: [String]
        var errorDescription: String? {
            "Discarded incomplete dataset: \(sources.joined(separator: ", "))"
        }
    }

    private actor FailureLog {
        private(set) var sources: Set<String> = []
        func add(_ source: String) { sources.insert(source) }
    }
}
