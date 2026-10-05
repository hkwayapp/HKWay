//
//  AppLocationManager.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import Foundation
import CoreLocation
import Observation

@Observable
final class AppLocationManager: NSObject,
                                CLLocationManagerDelegate {

    private let manager =
        CLLocationManager()

    private(set) var location: CLLocation?
    private(set) var authorizationStatus:
        CLAuthorizationStatus = .notDetermined

    private(set) var error: Error?

    private var isRequestInFlight = false

    private var refinementAttempt = 0
    private var bestRefinementLocation: CLLocation?
    private var lastRequestFinishedAt: Date?

    private let targetAccuracy:
        CLLocationAccuracy = 50

    private let maximumRefinementAttempts = 3

    private let recentLocationAge:
        TimeInterval = 30

    private let requestCooldown:
        TimeInterval = 30

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy =
            kCLLocationAccuracyBest
        manager.distanceFilter =
            kCLDistanceFilterNone

        authorizationStatus =
            manager.authorizationStatus

        useRecentCachedLocation()
    }

    func requestLocation(force: Bool = false) {

        switch manager.authorizationStatus {

        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse,
             .authorizedAlways:
            useRecentCachedLocation()

            guard !isRequestInFlight else {
                return
            }

            if !force, let lastRequestFinishedAt,
               Date().timeIntervalSince(
                    lastRequestFinishedAt
               ) < requestCooldown {
                return
            }

            if !force, let location,
               location.horizontalAccuracy <= targetAccuracy,
               location.timestamp.timeIntervalSinceNow >=
                    -recentLocationAge {
                return
            }

            beginLocationRequest()

        case .restricted,
             .denied:
            break

        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        authorizationStatus =
            manager.authorizationStatus

        switch manager.authorizationStatus {

        case .authorizedWhenInUse,
             .authorizedAlways:
            guard !isRequestInFlight else {
                return
            }

            beginLocationRequest()

        default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        var bestLocation: CLLocation?

        for candidate in locations {
            guard candidate.horizontalAccuracy >= 0 else {
                continue
            }

            if let currentBest = bestLocation {
                if candidate.horizontalAccuracy <
                    currentBest.horizontalAccuracy {
                    bestLocation = candidate
                }
            } else {
                bestLocation = candidate
            }
        }

        guard let bestLocation else {
            finishLocationRequest()
            return
        }

        if let currentBest = bestRefinementLocation {
            if bestLocation.horizontalAccuracy <
                currentBest.horizontalAccuracy {
                bestRefinementLocation = bestLocation
            }
        } else {
            bestRefinementLocation = bestLocation
        }

        if bestLocation.horizontalAccuracy <=
            targetAccuracy {
            location = bestLocation
            finishLocationRequest()
            return
        }

        if refinementAttempt <
            maximumRefinementAttempts {
            refinementAttempt += 1
            manager.requestLocation()
            return
        }

        if let bestRefinementLocation {
            location = bestAvailableLocation(
                current: location,
                candidate: bestRefinementLocation
            )
        }

        finishLocationRequest()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {

        finishLocationRequest()

        self.error = error
    }

    // MARK: - Cached Location

    private func useRecentCachedLocation() {
        guard
            manager.authorizationStatus ==
                .authorizedWhenInUse ||
            manager.authorizationStatus ==
                .authorizedAlways,
            let cachedLocation = manager.location,
            cachedLocation.horizontalAccuracy >= 0,
            cachedLocation.timestamp
                .timeIntervalSinceNow >=
                    -recentLocationAge
        else {
            return
        }

        if let location,
           location.timestamp >= cachedLocation.timestamp {
            return
        }

        location = cachedLocation
    }

    private func beginLocationRequest() {
        error = nil
        isRequestInFlight = true
        refinementAttempt = 1
        bestRefinementLocation = nil
        manager.requestLocation()
    }

    private func finishLocationRequest() {
        isRequestInFlight = false
        refinementAttempt = 0
        bestRefinementLocation = nil
        lastRequestFinishedAt = Date()
    }

    private func bestAvailableLocation(
        current: CLLocation?,
        candidate: CLLocation
    ) -> CLLocation {
        guard let current else {
            return candidate
        }

        if current.timestamp.timeIntervalSinceNow <
            -recentLocationAge {
            return candidate
        }

        return candidate.horizontalAccuracy <
            current.horizontalAccuracy
            ? candidate
            : current
    }
}
