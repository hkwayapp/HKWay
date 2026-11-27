//
//  MTRBusStopSequenceAligner.swift
//  HK Way
//

import Foundation

struct MTRBusStopSequenceAlignment {

    let matchedPairs: [MTRBusStopSequenceMatch]
    let transitGoOnly: [JourneyStop]
    let mtrBusOnly: [MTRBusStopRecord]

    var transitGoCoverage: Double {

        let total = matchedPairs.count +
            transitGoOnly.count

        guard total > 0 else {
            return 0
        }

        return Double(matchedPairs.count) /
            Double(total)
    }

    var averageDistanceMeters: Double? {

        guard !matchedPairs.isEmpty else {
            return nil
        }

        return matchedPairs.reduce(0) {
            $0 + $1.distanceMeters
        } / Double(matchedPairs.count)
    }
}

struct MTRBusStopSequenceMatch {

    let transitGoStop: JourneyStop
    let mtrBusStop: MTRBusStopRecord
    let distanceMeters: Double
}

struct MTRBusStopSequenceAligner {

    private let maximumMatchDistance = 500.0
    private let gapPenalty = 200.0

    func align(
        transitGoStops: [JourneyStop],
        mtrBusStops: [MTRBusStopRecord],
        localStopLookup: [String: Stop]
    ) -> MTRBusStopSequenceAlignment {

        let local = transitGoStops.sorted {
            $0.sequence < $1.sequence
        }

        let remote = mtrBusStops.sorted {
            $0.sequence < $1.sequence
        }

        let localCount = local.count
        let remoteCount = remote.count

        var cost = Array(
            repeating: Array(
                repeating: Double.infinity,
                count: remoteCount + 1
            ),
            count: localCount + 1
        )

        var action = Array(
            repeating: Array(
                repeating: MTRBusAlignmentAction.none,
                count: remoteCount + 1
            ),
            count: localCount + 1
        )

        cost[0][0] = 0

        if localCount > 0 {
            for index in 1...localCount {
                cost[index][0] =
                    Double(index) * gapPenalty
                action[index][0] = .skipCanonical
            }
        }

        if remoteCount > 0 {
            for index in 1...remoteCount {
                cost[0][index] =
                    Double(index) * gapPenalty
                action[0][index] = .skipMTRBus
            }
        }

        if localCount > 0 && remoteCount > 0 {
            for localIndex in 1...localCount {
                for remoteIndex in 1...remoteCount {

                    let pairDistance = distance(
                        transitGoStop:
                            local[localIndex - 1],
                        mtrBusStop:
                            remote[remoteIndex - 1],
                        localStopLookup:
                            localStopLookup
                    )

                    let pairNameSimilarity =
                        nameSimilarity(
                            transitGoStop:
                                local[localIndex - 1],
                            mtrBusStop:
                                remote[remoteIndex - 1],
                            localStopLookup:
                                localStopLookup
                        )

                    let matchCost =
                        cost[localIndex - 1][remoteIndex - 1] +
                        pairDistance +
                        namePenalty(
                            similarity:
                                pairNameSimilarity
                        )
                    let skipCanonicalCost =
                        cost[localIndex - 1][remoteIndex] +
                        gapPenalty
                    let skipMTRBusCost =
                        cost[localIndex][remoteIndex - 1] +
                        gapPenalty

                    let bestCost = min(
                        matchCost,
                        skipCanonicalCost,
                        skipMTRBusCost
                    )

                    cost[localIndex][remoteIndex] =
                        bestCost

                    if bestCost == matchCost {
                        action[localIndex][remoteIndex] =
                            .match
                    } else if bestCost ==
                        skipCanonicalCost {
                        action[localIndex][remoteIndex] =
                            .skipCanonical
                    } else {
                        action[localIndex][remoteIndex] =
                            .skipMTRBus
                    }
                }
            }
        }

        var matches: [MTRBusStopSequenceMatch] = []
        var transitGoOnly: [JourneyStop] = []
        var mtrBusOnly: [MTRBusStopRecord] = []
        var localIndex = localCount
        var remoteIndex = remoteCount

        while localIndex > 0 || remoteIndex > 0 {
            switch action[localIndex][remoteIndex] {
            case .match:
                let transitGoStop = local[localIndex - 1]
                let mtrBusStop = remote[remoteIndex - 1]

                matches.append(
                    MTRBusStopSequenceMatch(
                        transitGoStop: transitGoStop,
                        mtrBusStop: mtrBusStop,
                        distanceMeters: distance(
                            transitGoStop:
                                transitGoStop,
                            mtrBusStop:
                                mtrBusStop,
                            localStopLookup:
                                localStopLookup
                        )
                    )
                )
                localIndex -= 1
                remoteIndex -= 1

            case .skipCanonical:
                transitGoOnly.append(
                    local[localIndex - 1]
                )
                localIndex -= 1

            case .skipMTRBus:
                mtrBusOnly.append(
                    remote[remoteIndex - 1]
                )
                remoteIndex -= 1

            case .none:
                if localIndex > 0 {
                    transitGoOnly.append(
                        local[localIndex - 1]
                    )
                    localIndex -= 1
                } else {
                    mtrBusOnly.append(
                        remote[remoteIndex - 1]
                    )
                    remoteIndex -= 1
                }
            }
        }

        return MTRBusStopSequenceAlignment(
            matchedPairs: matches.reversed(),
            transitGoOnly: transitGoOnly.reversed(),
            mtrBusOnly: mtrBusOnly.reversed()
        )
    }

    private func distance(
        transitGoStop: JourneyStop,
        mtrBusStop: MTRBusStopRecord,
        localStopLookup: [String: Stop]
    ) -> Double {

        guard
            let localStop =
                localStopLookup[transitGoStop.stopId],
            (-90...90).contains(
                mtrBusStop.latitude
            ),
            (-180...180).contains(
                mtrBusStop.longitude
            )
        else {
            return .infinity
        }

        let result = distanceMeters(
            latitude1: localStop.latitude,
            longitude1: localStop.longitude,
            latitude2: mtrBusStop.latitude,
            longitude2: mtrBusStop.longitude
        )

        return result <= maximumMatchDistance
            ? result
            : .infinity
    }

    private func nameSimilarity(
        transitGoStop: JourneyStop,
        mtrBusStop: MTRBusStopRecord,
        localStopLookup: [String: Stop]
    ) -> Double {

        guard let localStop =
            localStopLookup[transitGoStop.stopId]
        else {
            return 0
        }

        let localTokens = normalizedNameTokens(
            localStop.nameEnglish
        )
        let remoteTokens = normalizedNameTokens(
            mtrBusStop.nameEnglish
        )

        guard
            !localTokens.isEmpty,
            !remoteTokens.isEmpty
        else {
            return 0
        }

        let intersection = localTokens
            .intersection(remoteTokens)

        return Double(intersection.count) /
            Double(
                max(
                    localTokens.count,
                    remoteTokens.count
                )
            )
    }

    private func namePenalty(
        similarity: Double
    ) -> Double {

        guard similarity >= 0.5 else {
            return .infinity
        }

        return (1 - similarity) * 100
    }

    private func normalizedNameTokens(
        _ name: String
    ) -> Set<String> {

        let ignoredTokens: Set<String> = [
            "bus",
            "terminus",
            "estate",
            "station",
            "mtr",
            "lr",
            "stop"
        ]

        let normalized = name
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()

        let tokens = normalized.split {
            !$0.isLetter && !$0.isNumber
        }
        .map(String.init)

        return Set(tokens).subtracting(
            ignoredTokens
        )
    }

    private func distanceMeters(
        latitude1: Double,
        longitude1: Double,
        latitude2: Double,
        longitude2: Double
    ) -> Double {

        let earthRadius = 6_371_000.0
        let latitude1Radians = latitude1 * .pi / 180
        let latitude2Radians = latitude2 * .pi / 180
        let latitudeDelta =
            (latitude2 - latitude1) * .pi / 180
        let longitudeDelta =
            (longitude2 - longitude1) * .pi / 180

        let value =
            sin(latitudeDelta / 2) *
            sin(latitudeDelta / 2) +
            cos(latitude1Radians) *
            cos(latitude2Radians) *
            sin(longitudeDelta / 2) *
            sin(longitudeDelta / 2)

        return earthRadius * 2 * atan2(
            sqrt(value),
            sqrt(1 - value)
        )
    }
}

private enum MTRBusAlignmentAction {
    case none
    case match
    case skipCanonical
    case skipMTRBus
}
