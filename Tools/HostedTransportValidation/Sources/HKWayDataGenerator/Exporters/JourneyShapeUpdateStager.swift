//
//  JourneyShapeUpdateStager.swift
//  HK Way
//

import Foundation

struct JourneyShapeUpdateStageResult {
    let shapeCount: Int
    let coordinateCount: Int
    let encodedByteCount: Int
    let version: DataVersion
}

struct JourneyShapeUpdateStager {

    func stage(
        shapes: [JourneyShape],
        currentVersion: DataVersion,
        to directory: URL,
        generatedAt: Date = Date()
    ) throws -> JourneyShapeUpdateStageResult {

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let shapeEncoder = JSONEncoder()
        shapeEncoder.outputFormatting = [.sortedKeys]
        let shapeData = try shapeEncoder.encode(shapes)

        try shapeData.write(
            to: directory.appendingPathComponent(
                "journey_shapes.json"
            ),
            options: .atomic
        )

        let version = DataVersion(
            version: nextVersion(
                after: currentVersion.version,
                generatedAt: generatedAt
            ),
            generatedAt: ISO8601DateFormatter()
                .string(from: generatedAt)
        )

        let metadataEncoder = JSONEncoder()
        metadataEncoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]
        try metadataEncoder.encode(version).write(
            to: directory.appendingPathComponent(
                "dataset_info.json"
            ),
            options: .atomic
        )

        return JourneyShapeUpdateStageResult(
            shapeCount: shapes.count,
            coordinateCount: shapes.reduce(0) {
                $0 + $1.coordinates.count
            },
            encodedByteCount: shapeData.count,
            version: version
        )
    }

    private func nextVersion(
        after currentVersion: String,
        generatedAt: Date
    ) -> String {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let dateVersion = formatter.string(
            from: generatedAt
        )

        guard currentVersion == dateVersion ||
            currentVersion.hasPrefix(
                dateVersion + "."
            )
        else {
            return dateVersion
        }

        let revision = currentVersion
            .split(separator: ".")
            .dropFirst(3)
            .first
            .flatMap { Int($0) } ?? 0

        return dateVersion + "." +
            String(revision + 1)
    }
}
