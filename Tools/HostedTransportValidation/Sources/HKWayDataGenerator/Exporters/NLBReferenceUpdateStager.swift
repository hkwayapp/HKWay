//
//  NLBReferenceUpdateStager.swift
//  HK Way
//

import Foundation

struct NLBReferenceUpdateStageResult {

    let referenceCount: Int
    let nlbReferenceCount: Int
    let version: DataVersion
}

struct NLBReferenceUpdateStager {

    private let merger =
        NLBOperatorStopReferenceMerger()

    func stage(
        existingReferences:
            [OperatorStopReference],
        replacementNLBReferences:
            [OperatorStopReference],
        to directory: URL,
        generatedAt: Date = Date()
    ) throws -> NLBReferenceUpdateStageResult {

        let merged = try merger.merge(
            existing: existingReferences,
            replacementNLBReferences:
                replacementNLBReferences
        )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let version = makeVersion(
            generatedAt: generatedAt
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

        return NLBReferenceUpdateStageResult(
            referenceCount: merged.count,
            nlbReferenceCount:
                replacementNLBReferences.count,
            version: version
        )
    }

    private func makeVersion(
        generatedAt: Date
    ) -> DataVersion {

        let versionFormatter = DateFormatter()
        versionFormatter.dateFormat = "yyyy.MM.dd"
        versionFormatter.timeZone =
            TimeZone(secondsFromGMT: 0)

        return DataVersion(
            version:
                versionFormatter.string(
                    from: generatedAt
                ),
            generatedAt:
                ISO8601DateFormatter()
                    .string(from: generatedAt)
        )
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

        let data = try encoder.encode(value)

        try data.write(
            to: url,
            options: .atomic
        )
    }
}
