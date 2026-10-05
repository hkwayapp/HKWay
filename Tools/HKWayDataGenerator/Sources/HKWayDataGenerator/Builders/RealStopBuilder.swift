//
//  RealStopBuilder.swift
//  HK Way
//
//  Created by Ken on 9/8/2026.
//

import Foundation

struct RealStopBuilder {

    private let stopReader = StopBusXMLReader()
    private let rStopReader = RStopBusXMLReader()
    private let coordinateConverter = HKGridConverter()

    func build() throws -> [Stop] {
        let stopURL = try resourceURL(
            name: "STOP_BUS",
            extension: "xml"
        )

        let rStopURL = try resourceURL(
            name: "RSTOP_BUS",
            extension: "xml"
        )

        let stopRecords = try stopReader.read(from: stopURL)
        let rStopRecords = try rStopReader.read(from: rStopURL)

        let namesByStopID = buildNames(
            from: rStopRecords
        )

        return try stopRecords.map { record in
            guard let names = namesByStopID[record.stopID] else {
                throw RealStopBuilderError.missingStopName(
                    record.stopID
                )
            }

            let coordinate = coordinateConverter.convert(
                easting: record.x,
                northing: record.y
            )

            return Stop(
                id: record.stopID,
                nameEnglish: names.english,
                nameTraditional: names.traditional,
                nameSimplified: names.simplified,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    private func buildNames(
        from records: [RStopBusRecord]
    ) -> [String: StopNames] {

        var result: [String: StopNames] = [:]

        for record in records {
            guard result[record.stopID] == nil else {
                continue
            }

            result[record.stopID] = StopNames(
                english: record.nameEnglish,
                traditional: record.nameTraditional,
                simplified: record.nameSimplified
            )
        }

        return result
    }

    private func resourceURL(
        name: String,
        extension: String
    ) throws -> URL {

        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: `extension`
        ) else {
            throw RealStopBuilderError.resourceNotFound(
                "\(name).xml"
            )
        }

        return url
    }
}

private struct StopNames {
    let english: String
    let traditional: String
    let simplified: String
}

enum RealStopBuilderError: Error {
    case resourceNotFound(String)
    case missingStopName(String)
}
