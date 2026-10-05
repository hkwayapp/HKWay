//
//  String+TransitDisplay.swift
//  HK Way
//

import Foundation

extension String {
    var transitDisplayName: String {
        split(whereSeparator: \.isWhitespace)
            .map {
                Self.formatTransitWord(String($0))
            }
            .joined(separator: " ")
    }

    private static let protectedTransitWords: Set<String> = [
        "BBI",
        "CTB",
        "CUHK",
        "HKBU",
        "HKIA",
        "HKU",
        "HKUST",
        "KMB",
        "LRT",
        "LWB",
        "MTR",
        "NLB",
        "NWFB",
        "VTC"
    ]

    private static func formatTransitWord(
        _ word: String
    ) -> String {
        for separator in ["-", "/"] {
            if word.contains(separator) {
                return word
                    .split(
                        separator: Character(separator),
                        omittingEmptySubsequences: false
                    )
                    .map {
                        formatTransitWord(String($0))
                    }
                    .joined(separator: separator)
            }
        }

        guard
            let firstCoreIndex = word.firstIndex(
                where: { $0.isLetter || $0.isNumber }
            ),
            let lastCoreIndex = word.lastIndex(
                where: { $0.isLetter || $0.isNumber }
            )
        else {
            return word
        }

        let prefix = String(word[..<firstCoreIndex])
        let suffixStart = word.index(after: lastCoreIndex)
        let suffix = String(word[suffixStart...])
        let core = String(word[firstCoreIndex...lastCoreIndex])
        let uppercaseCore = core.uppercased()

        let formattedCore: String

        if protectedTransitWords.contains(uppercaseCore) ||
            isRomanNumeral(uppercaseCore) ||
            core.contains(where: \.isNumber)
        {
            formattedCore = uppercaseCore
        } else {
            formattedCore = core.lowercased()
                .prefix(1).uppercased() +
                core.lowercased().dropFirst()
        }

        return prefix + formattedCore + suffix
    }

    private static func isRomanNumeral(
        _ value: String
    ) -> Bool {
        guard !value.isEmpty, value.count <= 8 else {
            return false
        }

        return value.allSatisfy {
            "IVXLCDM".contains($0)
        }
    }
}
