//
//  NLBOperatorStopReferenceMerger.swift
//  HK Way
//

import Foundation

enum NLBOperatorStopReferenceMergeError: Error {
    case nonNLBReplacement(String)
    case duplicateReference(String)
}

struct NLBOperatorStopReferenceMerger {

    func merge(
        existing: [OperatorStopReference],
        replacementNLBReferences:
            [OperatorStopReference]
    ) throws -> [OperatorStopReference] {

        for reference in
            replacementNLBReferences {

            guard reference.operatorId == "NLB" else {
                throw NLBOperatorStopReferenceMergeError
                    .nonNLBReplacement(
                        reference.operatorId
                    )
            }
        }

        let merged =
            existing.filter {
                $0.operatorId != "NLB"
            } + replacementNLBReferences

        var seenKeys: Set<String> = []

        for reference in merged {

            let key = referenceKey(reference)

            guard seenKeys.insert(key).inserted else {
                throw NLBOperatorStopReferenceMergeError
                    .duplicateReference(key)
            }
        }

        return merged
    }

    private func referenceKey(
        _ reference: OperatorStopReference
    ) -> String {

        [
            reference.operatorId,
            reference.journeyId,
            String(reference.sequence)
        ]
        .joined(separator: "|")
    }
}
