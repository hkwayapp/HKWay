//
//  CTBStopSequenceAligner.swift
//  HK Way
//
//  Created by Ken on 15/8/2026.
//

import Foundation

struct CTBStopSequenceAlignment {

    let matchedPairs: [CTBStopSequenceMatch]

    let transitGoOnly: [JourneyStop]

    let ctbOnly: [CTBRouteStopRecord]
}

struct CTBStopSequenceMatch {

    let transitGoStop: JourneyStop
    let ctbStop: CTBRouteStopRecord
    let distanceMeters: Double
}

struct CTBStopSequenceAligner {

    func align(
        transitGoStops: [JourneyStop],
        ctbStops: [CTBRouteStopRecord],
        localStopLookup: [String: Stop],
        ctbStopLookup: [String: CTBStopRecord]
    ) -> CTBStopSequenceAlignment {

        let local =
            transitGoStops.sorted {
                $0.sequence < $1.sequence
            }

        let remote =
            ctbStops.sorted {
                $0.sequence < $1.sequence
            }

        let n = local.count
        let m = remote.count

        var dp =
            Array(
                repeating:
                    Array(
                        repeating:
                            Double.infinity,
                        count: m + 1
                    ),
                count: n + 1
            )

        var action =
            Array(
                repeating:
                    Array(
                        repeating:
                            CTBAlignmentAction.none,
                        count: m + 1
                    ),
                count: n + 1
            )

        dp[0][0] = 0

        let gapPenalty = 1_000.0

        for i in 1...n {
            dp[i][0] =
                Double(i) * gapPenalty

            action[i][0] =
                .skipCanonical
        }

        for j in 1...m {
            dp[0][j] =
                Double(j) * gapPenalty

            action[0][j] =
                .skipCTB
        }

        if n > 0 && m > 0 {

            for i in 1...n {

                for j in 1...m {

                    let localStop =
                        local[i - 1]

                    let remoteStop =
                        remote[j - 1]

                    let pairCost =
                        distanceCost(
                            transitGoStop:
                                localStop,
                            ctbStop:
                                remoteStop,
                            localStopLookup:
                                localStopLookup,
                            ctbStopLookup:
                                ctbStopLookup
                        )

                    let matchCost =
                        dp[i - 1][j - 1] +
                        pairCost

                    let skipCanonicalCost =
                        dp[i - 1][j] +
                        gapPenalty

                    let skipCTBCost =
                        dp[i][j - 1] +
                        gapPenalty

                    let best =
                        min(
                            matchCost,
                            skipCanonicalCost,
                            skipCTBCost
                        )

                    dp[i][j] = best

                    if best == matchCost {

                        action[i][j] =
                            .match

                    } else if best ==
                        skipCanonicalCost {

                        action[i][j] =
                            .skipCanonical

                    } else {

                        action[i][j] =
                            .skipCTB
                    }
                }
            }
        }

        var matches:
            [CTBStopSequenceMatch] = []

        var transitGoOnly:
            [JourneyStop] = []

        var ctbOnly:
            [CTBRouteStopRecord] = []

        var i = n
        var j = m

        while i > 0 || j > 0 {

            switch action[i][j] {

            case .match:

                let localStop =
                    local[i - 1]

                let remoteStop =
                    remote[j - 1]

                let distance =
                    distanceCost(
                        transitGoStop:
                            localStop,
                        ctbStop:
                            remoteStop,
                        localStopLookup:
                            localStopLookup,
                        ctbStopLookup:
                            ctbStopLookup
                    )

                matches.append(
                    CTBStopSequenceMatch(
                        transitGoStop:
                            localStop,
                        ctbStop:
                            remoteStop,
                        distanceMeters:
                            distance
                    )
                )

                i -= 1
                j -= 1

            case .skipCanonical:

                transitGoOnly.append(
                    local[i - 1]
                )

                i -= 1

            case .skipCTB:

                ctbOnly.append(
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

                    ctbOnly.append(
                        remote[j - 1]
                    )

                    j -= 1
                }
            }
        }

        return CTBStopSequenceAlignment(
            matchedPairs:
                matches.reversed(),
            transitGoOnly:
                transitGoOnly.reversed(),
            ctbOnly:
                ctbOnly.reversed()
        )
    }

    private func distanceCost(
        transitGoStop: JourneyStop,
        ctbStop: CTBRouteStopRecord,
        localStopLookup: [String: Stop],
        ctbStopLookup:
            [String: CTBStopRecord]
    ) -> Double {

        guard
            let localStop =
                localStopLookup[
                    transitGoStop.stopId
                ],
            let remoteStop =
                ctbStopLookup[
                    ctbStop.stop
                ],
            let remoteLatitude =
                remoteStop.latitudeValue,
            let remoteLongitude =
                remoteStop.longitudeValue
        else {
            return 10_000
        }

        let distance =
            distanceMeters(
                latitude1:
                    localStop.latitude,
                longitude1:
                    localStop.longitude,
                latitude2:
                    remoteLatitude,
                longitude2:
                    remoteLongitude
            )

        let nameMatches =
            namesMatch(
                transitGoName:
                    localStop.nameEnglish,
                ctbName:
                    remoteStop.nameEnglish
            )

        if nameMatches {

            // Matching names are strong evidence that
            // these represent the same physical stop.
            return distance
        }

        // One sequence gap currently costs 1,000.
        //
        // A clearly different stop name should therefore
        // make skipping a stop more attractive than
        // accepting a geographically nearby but
        // semantically wrong match.

        let nameMismatchPenalty =
            2_000.0

        return distance +
            nameMismatchPenalty
    }

    private func normalizedName(
        _ name: String
    ) -> String {

        var value =
            name.lowercased()

        // HK Way names sometimes contain:
        // "ARSENAL STREET/<br>Arsenal Street, Hennessy Road"

        value =
            value.replacingOccurrences(
                of: "<br>",
                with: " "
            )

        value =
            value.replacingOccurrences(
                of: "/",
                with: " "
            )

        // Remove punctuation while preserving
        // letters, numbers and spaces.

        value =
            value.unicodeScalars
                .map { scalar -> Character in

                    if CharacterSet
                        .alphanumerics
                        .contains(scalar) {

                        return Character(
                            String(scalar)
                        )
                    }

                    return " "
                }
                .reduce(into: "") {
                    $0.append($1)
                }

        // Collapse repeated whitespace.

        return value
            .split {
                $0.isWhitespace
            }
            .joined(separator: " ")
    }

    private func namesMatch(
        transitGoName: String,
        ctbName: String
    ) -> Bool {

        let local =
            normalizedName(
                transitGoName
            )

        let remote =
            normalizedName(
                ctbName
            )

        guard
            !local.isEmpty,
            !remote.isEmpty
        else {
            return false
        }

        // MARK: - Exact / Contained

        let compactLocal =
            local.replacingOccurrences(
                of: " ",
                with: ""
            )

        let compactRemote =
            remote.replacingOccurrences(
                of: " ",
                with: ""
            )

        if compactLocal == compactRemote {
            return true
        }

        // MARK: - Compact Containment
        //
        // Handles spacing differences such as:
        //
        // LAKE SIDE GARDEN
        // Lakeside Garden, Hiram's Highway
        //
        // Require a reasonably long compact name so that
        // short/generic stop names do not match too easily.

        
        
        let shorterCompact =
            compactLocal.count <= compactRemote.count
                ? compactLocal
                : compactRemote

        let longerCompact =
            compactLocal.count <= compactRemote.count
                ? compactRemote
                : compactLocal

        if shorterCompact.count >= 10 &&
            longerCompact.contains(shorterCompact) {

            return true
        }

        if local.contains(remote) ||
            remote.contains(local) {

            return true
        }

        // MARK: - Token Comparison

        let localTokens =
            normalizedTokens(
                local
            )

        let remoteTokens =
            normalizedTokens(
                remote
            )

        guard
            !localTokens.isEmpty,
            !remoteTokens.isEmpty
        else {
            return false
        }

        let intersection =
            localTokens.intersection(
                remoteTokens
            )

        let smallerCount =
            min(
                localTokens.count,
                remoteTokens.count
            )

        guard smallerCount > 0 else {
            return false
        }

        let overlap =
            Double(intersection.count) /
            Double(smallerCount)

        // Require substantial agreement.
        //
        // This allows:
        //
        // NORTH POINT GOVT PRIMARY SCHOOL
        // North Point Government Primary School
        //
        // while avoiding weak matches based on
        // only one common road/location word.

        return overlap >= 0.75
    }
    
    private func normalizedTokens(
        _ name: String
    ) -> Set<String> {

        let aliases:
            [String: String] = [

                "govt":
                    "government",

                "gov":
                    "government",

                "bbi":
                    "businterchange",

                "interchange":
                    "businterchange",

                "tunnel":
                    "crossing",

                "rd":
                    "road",

                "st":
                    "street"
            ]

        let ignored:
            Set<String> = [
                "the"
            ]

        var result:
            Set<String> = []

        for token in
            name.split(separator: " ") {

            var value =
                String(token)

            if ignored.contains(value) {
                continue
            }

            if let alias =
                aliases[value] {

                value = alias
            }

            result.insert(value)
        }

        return result
    }
    
    private func distanceMeters(
        latitude1: Double,
        longitude1: Double,
        latitude2: Double,
        longitude2: Double
    ) -> Double {

        let earthRadius =
            6_371_000.0

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

private enum CTBAlignmentAction {
    case none
    case match
    case skipCanonical
    case skipCTB
}
