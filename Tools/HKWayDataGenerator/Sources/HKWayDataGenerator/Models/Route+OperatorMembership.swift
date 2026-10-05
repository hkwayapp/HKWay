//
//  Route+OperatorMembership.swift
//  HK Way
//
//  Created by Ken on 17/8/2026.
//

import Foundation

extension Route {

    var componentOperatorIds: Set<String> {

        Set(
            operatorIds.flatMap { value in

                value
                    .split(separator: "+")
                    .map {
                        String($0)
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                    }
            }
        )
    }

    func supportsOperator(
        _ operatorId: String
    ) -> Bool {

        componentOperatorIds.contains(
            operatorId
        )
    }
}
