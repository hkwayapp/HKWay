//
//  MTRBusReferenceMerger.swift
//  HK Way
//

import Foundation

enum MTRBusReferenceMergeError: Error {
    case invalidReplacement(String)
    case duplicateReference(String)
}

struct MTRBusReferenceMerger {

    func merge(
        existing: [OperatorStopReference],
        replacementReferences:
            [OperatorStopReference]
    ) throws -> [OperatorStopReference] {

        for reference in replacementReferences {
            guard
                reference.operatorId == "LRTFeeder",
                !reference.operatorServiceType.isEmpty,
                !reference.operatorStopId.isEmpty
            else {
                throw MTRBusReferenceMergeError
                    .invalidReplacement(
                        reference.journeyId
                    )
            }
        }

        let merged = existing.filter {
            $0.operatorId != "LRTFeeder"
        } + replacementReferences

        var seenKeys: Set<String> = []

        for reference in merged {
            let key = [
                reference.operatorId,
                reference.journeyId,
                String(reference.sequence)
            ]
            .joined(separator: "|")

            guard seenKeys.insert(key).inserted else {
                throw MTRBusReferenceMergeError
                    .duplicateReference(key)
            }
        }

        return merged
    }
}
