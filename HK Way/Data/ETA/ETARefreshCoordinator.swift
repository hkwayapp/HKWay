//
//  ETARefreshCoordinator.swift
//  HK Way
//

import Foundation

actor ETARefreshCoordinator {

    static let shared = ETARefreshCoordinator()

    static let refreshInterval: Duration =
        .seconds(45)

    private let maximumConcurrentRequests = 4
    private var activeRequestCount = 0
    private var waiters:
        [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if activeRequestCount < maximumConcurrentRequests {
            activeRequestCount += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            activeRequestCount = max(
                activeRequestCount - 1,
                0
            )
        } else {
            let continuation = waiters.removeFirst()
            continuation.resume()
        }
    }
}
