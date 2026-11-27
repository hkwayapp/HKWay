//
//  OperatorValidator.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct OperatorValidator {

    func validate(
        _ operators: [Operator]
    ) {

        var ids = Set<String>()

        for op in operators {
            guard ids.insert(op.id).inserted else {
                fatalError("Duplicate Operator ID: \(op.id)")
            }
            
            guard !op.id.isEmpty else {
                fatalError("Operator ID cannot be empty")
            }

            guard !op.nameEnglish.isEmpty else {
                fatalError("Operator name cannot be empty")
            }
            
        }

    }

}
