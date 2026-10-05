//
//  RealJourneyStopBuilder.swift
//  HK Way
//
//  Created by Ken on 10/8/2026.
//

import Foundation

struct RealJourneyStopBuilder {

    private let rStopReader = RStopBusXMLReader()

    func build() throws -> [JourneyStop] {
        let url = try resourceURL()

        let records = try rStopReader.read(from: url)

        return records.map { record in
            JourneyStop(
                journeyId: "\(record.routeID)-\(record.routeSequence)",
                stopId: record.stopID,
                sequence: record.stopSequence,
                stopPickDrop: ["1", "2"].contains(record.stopPickDrop)
                    ? record.stopPickDrop
                    : nil
            )
        }
    }

    private func resourceURL() throws -> URL {
        guard let url = Bundle.module.url(
            forResource: "RSTOP_BUS",
            withExtension: "xml"
        ) else {
            throw RealJourneyStopBuilderError.resourceNotFound
        }

        return url
    }
}

enum RealJourneyStopBuilderError: Error {
    case resourceNotFound
}
