//
//  NLBStopSequenceAligner.swift
//  HK Way
//

import Foundation

struct NLBStopSequenceAlignment {

    let matchedPairs: [NLBStopSequenceMatch]
    let transitGoOnly: [JourneyStop]
    let nlbOnly: [NLBSequencedStop]

    var transitGoCoverage: Double {

        let total =
            matchedPairs.count +
            transitGoOnly.count

        guard total > 0 else {
            return 0
        }

        return Double(matchedPairs.count) /
            Double(total)
    }
}

struct NLBStopSequenceMatch {

    let transitGoStop: JourneyStop
    let nlbStop: NLBRouteStopRecord
    let nlbSequence: Int
    let distanceMeters: Double
}

struct NLBSequencedStop {

    let stop: NLBRouteStopRecord
    let sequence: Int
}

struct NLBStopSequenceAligner {

    private let maximumMatchDistance =
        500.0

    private let gapPenalty =
        300.0

    func align(
        transitGoStops: [JourneyStop],
        nlbStops: [NLBRouteStopRecord],
        localStopLookup: [String: Stop]
    ) -> NLBStopSequenceAlignment {

        let local =
            transitGoStops.sorted {
                $0.sequence < $1.sequence
            }

        let remote =
            nlbStops.enumerated().map {
                NLBSequencedStop(
                    stop: $0.element,
                    sequence: $0.offset + 1
                )
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
                repeating: NLBAlignmentAction.none,
                count: remoteCount + 1
            ),
            count: localCount + 1
        )

        cost[0][0] = 0

        if localCount > 0 {
            for index in 1...localCount {
                cost[index][0] =
                    Double(index) * gapPenalty

                action[index][0] =
                    .skipCanonical
            }
        }

        if remoteCount > 0 {
            for index in 1...remoteCount {
                cost[0][index] =
                    Double(index) * gapPenalty

                action[0][index] =
                    .skipNLB
            }
        }

        if localCount > 0 && remoteCount > 0 {
            for localIndex in 1...localCount {
                for remoteIndex in 1...remoteCount {

                    let pairDistance = distance(
                        transitGoStop:
                            local[localIndex - 1],
                        nlbStop:
                            remote[remoteIndex - 1].stop,
                        localStopLookup:
                            localStopLookup
                    )

                    let matchCost =
                        cost[localIndex - 1][remoteIndex - 1] +
                        pairDistance

                    let skipCanonicalCost =
                        cost[localIndex - 1][remoteIndex] +
                        gapPenalty

                    let skipNLBCost =
                        cost[localIndex][remoteIndex - 1] +
                        gapPenalty

                    let bestCost = min(
                        matchCost,
                        skipCanonicalCost,
                        skipNLBCost
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
                            .skipNLB
                    }
                }
            }
        }

        var matches: [NLBStopSequenceMatch] = []
        var transitGoOnly: [JourneyStop] = []
        var nlbOnly: [NLBSequencedStop] = []

        var localIndex = localCount
        var remoteIndex = remoteCount

        while localIndex > 0 || remoteIndex > 0 {

            switch action[localIndex][remoteIndex] {
            case .match:

                let transitGoStop =
                    local[localIndex - 1]

                let nlbStop =
                    remote[remoteIndex - 1]

                matches.append(
                    NLBStopSequenceMatch(
                        transitGoStop:
                            transitGoStop,
                        nlbStop:
                            nlbStop.stop,
                        nlbSequence:
                            nlbStop.sequence,
                        distanceMeters:
                            distance(
                                transitGoStop:
                                    transitGoStop,
                                nlbStop:
                                    nlbStop.stop,
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

            case .skipNLB:
                nlbOnly.append(
                    remote[remoteIndex - 1]
                )
                remoteIndex -= 1

            case .none:
                if localIndex > 0 {
                    transitGoOnly.append(
                        local[localIndex - 1]
                    )
                    localIndex -= 1
                } else if remoteIndex > 0 {
                    nlbOnly.append(
                        remote[remoteIndex - 1]
                    )
                    remoteIndex -= 1
                }
            }
        }

        return NLBStopSequenceAlignment(
            matchedPairs:
                matches.reversed(),
            transitGoOnly:
                transitGoOnly.reversed(),
            nlbOnly:
                nlbOnly.reversed()
        )
    }

    private func distance(
        transitGoStop: JourneyStop,
        nlbStop: NLBRouteStopRecord,
        localStopLookup: [String: Stop]
    ) -> Double {

        guard
            let localStop =
                localStopLookup[
                    transitGoStop.stopId
                ],
            let latitude =
                Double(nlbStop.latitude),
            let longitude =
                Double(nlbStop.longitude),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else {
            return .infinity
        }

        let result = distanceMeters(
            latitude1: localStop.latitude,
            longitude1: localStop.longitude,
            latitude2: latitude,
            longitude2: longitude
        )

        guard result <= maximumMatchDistance else {
            return .infinity
        }

        return result
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

private enum NLBAlignmentAction {
    case none
    case match
    case skipCanonical
    case skipNLB
}
