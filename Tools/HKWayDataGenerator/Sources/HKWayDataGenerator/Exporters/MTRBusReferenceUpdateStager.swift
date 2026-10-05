//
//  MTRBusReferenceUpdateStager.swift
//  HK Way
//

import Foundation

struct MTRBusReferenceUpdateStageResult {
    let referenceCount: Int
    let mtrBusReferenceCount: Int
    let version: DataVersion
}

struct MTRBusReferenceUpdateStager {

    func stage(
        existingReferences:
            [OperatorStopReference],
        replacementReferences:
            [OperatorStopReference],
        currentVersion: DataVersion,
        to directory: URL,
        generatedAt: Date = Date()
    ) throws
        -> MTRBusReferenceUpdateStageResult {

        let merged = try
            MTRBusReferenceMerger().merge(
                existing: existingReferences,
                replacementReferences:
                    replacementReferences
            )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let version = DataVersion(
            version: nextVersion(
                after: currentVersion.version,
                generatedAt: generatedAt
            ),
            generatedAt: ISO8601DateFormatter()
                .string(from: generatedAt)
        )

        try encode(
            merged,
            to: directory.appendingPathComponent(
                "operator_stop_references.json"
            )
        )
        try encode(
            version,
            to: directory.appendingPathComponent(
                "dataset_info.json"
            )
        )

        return MTRBusReferenceUpdateStageResult(
            referenceCount: merged.count,
            mtrBusReferenceCount:
                replacementReferences.count,
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

    private func encode<T: Encodable>(
        _ value: T,
        to url: URL
    ) throws {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        try encoder.encode(value).write(
            to: url,
            options: .atomic
        )
    }
}
