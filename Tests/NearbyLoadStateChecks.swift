import Foundation
import CoreLocation

@main enum NearbyLoadStateChecks {
    static func main() {
        let location = CLLocation(latitude: 22.37, longitude: 114.11)
        var state = NearbyLoadState()
        let first = state.begin()
        precondition(state.isLoading && state.resolvedLocation == nil)
        state.cancel()
        precondition(!state.isLoading)
        precondition(state.shouldLoad(location: location, indexReady: true, hasMatches: false, force: false))
        let second = state.begin()
        state.finish(first, location: location)
        precondition(state.isLoading && state.resolvedLocation == nil)
        state.finish(second, location: location)
        precondition(!state.isLoading && state.resolvedLocation != nil)
        precondition(!state.shouldLoad(location: location, indexReady: true, hasMatches: true, force: false))
        precondition(state.shouldLoad(location: location, indexReady: true, hasMatches: false, force: false))
        precondition(state.shouldLoad(location: location, indexReady: true, hasMatches: true, force: true))
        precondition(state.shouldLoad(location: location, indexReady: false, hasMatches: true, force: false))
        let moved = CLLocation(latitude: 22.371, longitude: 114.11)
        precondition(state.shouldLoad(location: moved, indexReady: true, hasMatches: true, force: false))
        let third = state.begin()
        let fourth = state.begin()
        state.finish(third)
        precondition(state.isLoading && state.requestID == fourth)
        state.cancel(invalidateLocation: true)
        precondition(!state.isLoading && state.resolvedLocation == nil)
        state.finish(fourth, location: location)
        precondition(state.resolvedLocation == nil)
        print("Nearby loading checks passed: cancelled first load, same-location retry, stale completion, empty results, movement and invalidation.")
    }
}
