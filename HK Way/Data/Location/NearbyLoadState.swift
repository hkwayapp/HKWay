import CoreLocation

// Only completed matches may suppress a later search at the same location.
struct NearbyLoadState {
    private(set) var requestID = 0
    private(set) var isLoading = false
    private(set) var resolvedLocation: CLLocation?

    mutating func begin() -> Int {
        requestID += 1
        isLoading = true
        return requestID
    }

    mutating func cancel(invalidateLocation: Bool = false) {
        requestID += 1
        isLoading = false
        if invalidateLocation { resolvedLocation = nil }
    }

    mutating func finish(_ id: Int, location: CLLocation? = nil) {
        guard id == requestID else { return }
        if let location { resolvedLocation = location }
        isLoading = false
    }

    func shouldLoad(location: CLLocation, indexReady: Bool, hasMatches: Bool, force: Bool) -> Bool {
        guard !force, !isLoading, indexReady, hasMatches, let resolvedLocation else { return true }
        return location.distance(from: resolvedLocation) >= 10 ||
            resolvedLocation.horizontalAccuracy - location.horizontalAccuracy >= 10
    }
}
