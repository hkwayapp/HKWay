//
//  KMBStopSequenceAligner.swift
//  HK Way
//
//  Created by Ken on 12/8/2026.
//

import Foundation

struct KMBStopSequenceAlignment {

    let matchedPairs: [KMBStopSequenceMatch]

    let transitGoOnly: [JourneyStop]

    let kmbOnly: [KMBRouteStopRecord]
}

struct KMBStopSequenceMatch {

    let transitGoStop: JourneyStop
    let kmbStop: KMBRouteStopRecord
    let distanceMeters: Double
}

struct KMBStopSequenceAligner {

    func align(
        transitGoStops: [JourneyStop],
        kmbStops: [KMBRouteStopRecord],
        localStopLookup: [String: Stop],
        kmbStopLookup: [String: KMBStopRecord]
    ) -> KMBStopSequenceAlignment {

        let local = transitGoStops.sorted {
            $0.sequence < $1.sequence
        }

        let remote = kmbStops.sorted {
            ($0.sequence ?? 0) < ($1.sequence ?? 0)
        }

        let n = local.count
        let m = remote.count

        var dp = Array(
            repeating: Array(
                repeating: Double.infinity,
                count: m + 1
            ),
            count: n + 1
        )

        var action = Array(
            repeating: Array(
                repeating: AlignmentAction.none,
                count: m + 1
            ),
            count: n + 1
        )

        dp[0][0] = 0

        let gapPenalty = 1_000.0

        for i in 1...n {
            dp[i][0] = Double(i) * gapPenalty
            action[i][0] = .skipCanonical
        }

        for j in 1...m {
            dp[0][j] = Double(j) * gapPenalty
            action[0][j] = .skipKMB
        }

        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {

                    let localStop = local[i - 1]
                    let remoteStop = remote[j - 1]

                    let pairCost = distanceCost(
                        transitGoStop: localStop,
                        kmbStop: remoteStop,
                        localStopLookup: localStopLookup,
                        kmbStopLookup: kmbStopLookup
                    )

                    let matchCost =
                        dp[i - 1][j - 1] + pairCost

                    let skipCanonicalCost =
                        dp[i - 1][j] + gapPenalty

                    let skipKMBCost =
                        dp[i][j - 1] + gapPenalty

                    let best = min(
                        matchCost,
                        skipCanonicalCost,
                        skipKMBCost
                    )

                    dp[i][j] = best

                    if best == matchCost {
                        action[i][j] = .match
                    } else if best == skipCanonicalCost {
                        action[i][j] = .skipCanonical
                    } else {
                        action[i][j] = .skipKMB
                    }
                }
            }
        }

        var matches: [KMBStopSequenceMatch] = []
        var transitGoOnly: [JourneyStop] = []
        var kmbOnly: [KMBRouteStopRecord] = []

        var i = n
        var j = m

        while i > 0 || j > 0 {

            switch action[i][j] {

            case .match:

                let localStop = local[i - 1]
                let remoteStop = remote[j - 1]

                let distance = distanceCost(
                    transitGoStop: localStop,
                    kmbStop: remoteStop,
                    localStopLookup: localStopLookup,
                    kmbStopLookup: kmbStopLookup
                )

                matches.append(
                    KMBStopSequenceMatch(
                        transitGoStop: localStop,
                        kmbStop: remoteStop,
                        distanceMeters: distance
                    )
                )

                i -= 1
                j -= 1

            case .skipCanonical:

                transitGoOnly.append(
                    local[i - 1]
                )

                i -= 1

            case .skipKMB:

                kmbOnly.append(
                    remote[j - 1]
                )

                j -= 1

            case .none:

                if i > 0 {
                    transitGoOnly.append(
                        local[i - 1]
                    )

                    i -= 1
                } else if j > 0 {
                    kmbOnly.append(
                        remote[j - 1]
                    )

                    j -= 1
                }
            }
        }

        return KMBStopSequenceAlignment(
            matchedPairs: matches.reversed(),
            transitGoOnly: transitGoOnly.reversed(),
            kmbOnly: kmbOnly.reversed()
        )
    }

    private func distanceCost(
        transitGoStop: JourneyStop,
        kmbStop: KMBRouteStopRecord,
        localStopLookup: [String: Stop],
        kmbStopLookup: [String: KMBStopRecord]
    ) -> Double {

        guard
            let localStop =
                localStopLookup[transitGoStop.stopId],
            let remoteStop =
                kmbStopLookup[kmbStop.stop],
            let remoteLatitude =
                remoteStop.latitudeValue,
            let remoteLongitude =
                remoteStop.longitudeValue
        else {
            return 10_000
        }

        return distanceMeters(
            latitude1: localStop.latitude,
            longitude1: localStop.longitude,
            latitude2: remoteLatitude,
            longitude2: remoteLongitude
        )
    }

    private func distanceMeters(
        latitude1: Double,
        longitude1: Double,
        latitude2: Double,
        longitude2: Double
    ) -> Double {

        let earthRadius = 6_371_000.0

        let lat1 =
            latitude1 * .pi / 180

        let lat2 =
            latitude2 * .pi / 180

        let deltaLat =
            (latitude2 - latitude1) *
            .pi / 180

        let deltaLon =
            (longitude2 - longitude1) *
            .pi / 180

        let a =
            sin(deltaLat / 2) *
            sin(deltaLat / 2) +
            cos(lat1) *
            cos(lat2) *
            sin(deltaLon / 2) *
            sin(deltaLon / 2)

        let c =
            2 * atan2(
                sqrt(a),
                sqrt(1 - a)
            )

        return earthRadius * c
    }
}

private enum AlignmentAction {
    case none
    case match
    case skipCanonical
    case skipKMB
}
