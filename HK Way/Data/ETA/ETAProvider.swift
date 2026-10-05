//
//  ETAProvider.swift
//  HK Way
//
//  Created by Ken on 13/8/2026.
//

import Foundation

enum ETAProviderError: Error {
    case unsupportedOperator(String)
    case invalidOperatorServiceType(String)
}

struct ETAOperatorReference: Sendable {
    let operatorId: String
    let operatorStopId: String
    let operatorServiceType: String
    let operatorDirection: String

    init(_ reference: OperatorStopReferenceEntity) {
        operatorId = reference.operatorId
        operatorStopId = reference.operatorStopId
        operatorServiceType = reference.operatorServiceType
        operatorDirection = reference.operatorDirection
    }
}

struct ETAProvider {

    nonisolated init() {}

    private let kmbService =
        KMBETAService()

    private let ctbService =
        CTBETAService()

    private let nlbService =
        NLBETAService()

    private let mtrBusService =
        MTRBusETAService()

    private let gmbService =
        GMBETAService()

    func fetchETA(
        reference: ETAOperatorReference,
        routeNumber: String
    ) async throws -> [TransitETA] {

        switch reference.operatorId {

        case "KMB", "LWB":

            return try await fetchKMBETA(
                reference: reference,
                routeNumber: routeNumber
            )

        case "CTB":

            return try await fetchCTBETA(
                reference: reference,
                routeNumber: routeNumber
            )

        case "NLB":

            return try await fetchNLBETA(
                reference: reference,
                routeNumber: routeNumber
            )

        case "LRTFeeder":

            return try await fetchMTRBusETA(
                reference: reference,
                routeNumber: routeNumber
            )

        case "GMB":

            return try await fetchGMBETA(
                reference: reference,
                routeNumber: routeNumber
            )

        default:

            throw ETAProviderError
                .unsupportedOperator(
                    reference.operatorId
                )
        }
    }

    // MARK: - Green Minibus

    private func fetchGMBETA(
        reference: ETAOperatorReference,
        routeNumber: String
    ) async throws -> [TransitETA] {

        let components = reference.operatorServiceType.split(
            separator: "|",
            omittingEmptySubsequences: false
        )

        guard
            components.count == 2,
            !components[0].isEmpty,
            !components[1].isEmpty,
            !reference.operatorDirection.isEmpty
        else {
            throw ETAProviderError.invalidOperatorServiceType(
                reference.operatorServiceType
            )
        }

        let records = try await gmbService.fetchETA(
            routeId: String(components[0]),
            routeSequence: reference.operatorDirection,
            stopSequence: String(components[1])
        )

        return records.map {
            makeTransitETA(
                from: $0,
                routeNumber: routeNumber
            )
        }
    }

    private func makeTransitETA(
        from source: GMBETA,
        routeNumber: String
    ) -> TransitETA {

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        let fallbackFormatter = ISO8601DateFormatter()
        let estimatedArrival = source.timestamp.flatMap {
            formatter.date(from: $0) ?? fallbackFormatter.date(from: $0)
        }

        return TransitETA(
            operatorId: "GMB",
            routeNumber: routeNumber,
            destinationTraditional: "",
            destinationSimplified: "",
            destinationEnglish: "",
            estimatedArrival: estimatedArrival,
            sequence: source.sequence,
            remarkTraditional: source.remarkTraditional,
            remarkSimplified: source.remarkSimplified,
            remarkEnglish: source.remarkEnglish
        )
    }

    // MARK: - KMB / LWB

    private func fetchKMBETA(
        reference: ETAOperatorReference,
        routeNumber: String
    ) async throws -> [TransitETA] {

        guard
            let serviceType =
                Int(
                    reference
                        .operatorServiceType
                )
        else {

            throw ETAProviderError
                .invalidOperatorServiceType(
                    reference
                        .operatorServiceType
                )
        }

        let records =
            try await kmbService.fetchETA(
                stopId:
                    reference.operatorStopId,
                route:
                    routeNumber,
                serviceType:
                    serviceType
            )

        let filteredRecords =
            records.filter {
                $0.dir ==
                    reference.operatorDirection
            }

        return filteredRecords.map {

            makeTransitETA(
                from: $0,
                operatorId:
                    reference.operatorId
            )
        }
    }

    private func makeTransitETA(
        from source: KMBETA,
        operatorId: String
    ) -> TransitETA {

        let formatter =
            ISO8601DateFormatter()

        let estimatedArrival =
            source.eta.flatMap {
                formatter.date(from: $0)
            }

        return TransitETA(
            operatorId:
                operatorId,
            routeNumber:
                source.route,
            destinationTraditional:
                source.destTC,
            destinationSimplified:
                source.destSC,
            destinationEnglish:
                source.destEN,
            estimatedArrival:
                estimatedArrival,
            sequence:
                source.etaSeq,
            remarkTraditional:
                source.rmkTC,
            remarkSimplified:
                source.rmkSC,
            remarkEnglish:
                source.rmkEN
        )
    }

    // MARK: - CTB

    private func fetchCTBETA(
        reference: ETAOperatorReference,
        routeNumber: String
    ) async throws -> [TransitETA] {

        let records =
            try await ctbService.fetchETA(
                stopId:
                    reference.operatorStopId,
                route:
                    routeNumber
            )


        let expectedDirection: String

        switch reference.operatorDirection {

        case "outbound":
            expectedDirection = "O"

        case "inbound":
            expectedDirection = "I"

        default:
            expectedDirection =
                reference.operatorDirection
        }

        let filteredRecords =
            records.filter {
                $0.direction ==
                    expectedDirection
            }

        return filteredRecords.map {

            makeTransitETA(
                from: $0,
                operatorId:
                    reference.operatorId
            )
        }
    }

    private func makeTransitETA(
        from source: CTBETA,
        operatorId: String
    ) -> TransitETA {

        let formatter =
            ISO8601DateFormatter()

        let estimatedArrival =
            source.eta.flatMap {
                formatter.date(from: $0)
            }

        return TransitETA(
            operatorId:
                operatorId,
            routeNumber:
                source.route,
            destinationTraditional:
                source.destinationTraditional,
            destinationSimplified:
                source.destinationSimplified,
            destinationEnglish:
                source.destinationEnglish,
            estimatedArrival:
                estimatedArrival,
            sequence:
                source.sequence ?? 0,
            remarkTraditional:
                source.remarkTraditional,
            remarkSimplified:
                source.remarkSimplified,
            remarkEnglish:
                source.remarkEnglish
        )
    }

    // MARK: - NLB

    private func fetchNLBETA(
        reference: ETAOperatorReference,
        routeNumber: String
    ) async throws -> [TransitETA] {

        let records = try await nlbService.fetchETA(
            routeId:
                reference.operatorServiceType,
            stopId:
                reference.operatorStopId
        )

        return records.enumerated().map {
            index,
            source in

            makeTransitETA(
                from: source,
                routeNumber: routeNumber,
                sequence: index + 1
            )
        }
    }

    private func makeTransitETA(
        from source: NLBETA,
        routeNumber: String,
        sequence: Int
    ) -> TransitETA {

        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        formatter.calendar = Calendar(
            identifier: .gregorian
        )
        formatter.timeZone = TimeZone(
            identifier: "Asia/Hong_Kong"
        )
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let isScheduled =
            source.departed != 1 ||
            source.noGPS == 1

        let remark = isScheduled
            ? "Scheduled"
            : ""

        return TransitETA(
            operatorId: "NLB",
            routeNumber: routeNumber,
            destinationTraditional:
                source.routeVariantName,
            destinationSimplified:
                source.routeVariantName,
            destinationEnglish:
                source.routeVariantName,
            estimatedArrival:
                formatter.date(
                    from:
                        source.estimatedArrivalTime
                ),
            sequence: sequence,
            remarkTraditional: remark,
            remarkSimplified: remark,
            remarkEnglish: remark
        )
    }

    // MARK: - MTR Bus / Feeder Bus

    private func fetchMTRBusETA(
        reference: ETAOperatorReference,
        routeNumber: String
    ) async throws -> [TransitETA] {

        let response = try await
            mtrBusService.fetchETA(
                routeName:
                    reference.operatorServiceType
            )

        guard
            let stop = response.busStop.first(
                where: {
                    $0.busStopId ==
                        reference.operatorStopId
                }
            ),
            stop.isSuspended != "1"
        else {
            return []
        }

        let requestTime = Date()

        return stop.bus.enumerated().compactMap {
            index,
            source in

            let secondsText =
                source.arrivalTimeText.isEmpty
                ? source.departureTimeInSecond
                : source.arrivalTimeInSecond

            guard
                let seconds = TimeInterval(
                    secondsText
                ),
                seconds >= 0,
                seconds < 86_400
            else {
                return nil
            }

            let remark = source.isScheduled == "1"
                ? "Scheduled"
                : ""

            return TransitETA(
                operatorId: "LRTFeeder",
                routeNumber: routeNumber,
                destinationTraditional:
                    source.lineRef,
                destinationSimplified:
                    source.lineRef,
                destinationEnglish:
                    source.lineRef,
                estimatedArrival:
                    requestTime.addingTimeInterval(
                        seconds
                    ),
                sequence: index + 1,
                remarkTraditional: remark,
                remarkSimplified: remark,
                remarkEnglish: remark
            )
        }
    }
}
