//
//  TransitETA.swift
//  HK Way
//
//  Created by Ken on 13/8/2026.
//

import Foundation

struct TransitETA: Identifiable, Sendable {

    let operatorId: String
    let routeNumber: String

    let destinationTraditional: String
    let destinationSimplified: String
    let destinationEnglish: String

    let estimatedArrival: Date?

    let sequence: Int

    let remarkTraditional: String
    let remarkSimplified: String
    let remarkEnglish: String

    var id: String {
        [
            operatorId,
            routeNumber,
            String(sequence),
            estimatedArrival?.ISO8601Format() ?? "nil"
        ]
        .joined(separator: "|")
    }
}

extension TransitETA {
    func displayDestination(
        for language: TransitLanguage
    ) -> String {
        let preferredDestination: String

        switch language {
        case .english:
            preferredDestination = destinationEnglish
        case .traditionalChinese:
            preferredDestination = destinationTraditional
        case .simplifiedChinese:
            preferredDestination = destinationSimplified
        }

        if !preferredDestination.isEmpty {
            return language == .english
                ? preferredDestination.transitDisplayName
                : preferredDestination
        }

        if !destinationEnglish.isEmpty {
            return destinationEnglish.transitDisplayName
        }

        if !destinationTraditional.isEmpty {
            return destinationTraditional
        }

        return destinationSimplified
    }
}
