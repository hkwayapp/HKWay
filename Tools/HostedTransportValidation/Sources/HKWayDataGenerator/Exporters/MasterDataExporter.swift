//
//  MasterDataExporter.swift
//  HK Way
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct MasterDataExporter {

    func export(
        _ data: MasterData,
        to directory: URL,
        metadata: DataVersion? = nil,
        shapes: [JourneyShape]? = nil
    ) throws {

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        try encode(data.operators, filename: "operators.json", directory: directory)
        try encode(data.routes, filename: "routes.json", directory: directory)
        try encode(data.journeys, filename: "journeys.json", directory: directory)
        try encode(data.journeyStops, filename: "journey_stops.json", directory: directory)
        try encode(data.stops, filename: "stops.json", directory: directory)
        try encode(data.schedules, filename: "schedules.json", directory: directory)

        let now = Date()

        let versionFormatter = DateFormatter()
        versionFormatter.dateFormat = "yyyy.MM.dd"
        versionFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let isoFormatter = ISO8601DateFormatter()

        let version = metadata ?? DataVersion(
            version: versionFormatter.string(from: now),
            generatedAt: isoFormatter.string(from: now)
        )

        try encode(
            data.operatorStopReferences,
            filename: "operator_stop_references.json",
            directory: directory
        )

        if let shapes {
            try encode(shapes, filename: "journey_shapes.json", directory: directory, prettyPrinted: false)
        }

        try encode(
            version,
            filename: "dataset_info.json",
            directory: directory
        )
    }

    private func encode<T: Encodable>(
        _ value: T,
        filename: String,
        directory: URL,
        prettyPrinted: Bool = true
    ) throws {

        let encoder = JSONEncoder()

        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]

        let data = try encoder.encode(value)

        let url = directory.appendingPathComponent(filename)

        try data.write(to: url)
    }
}
