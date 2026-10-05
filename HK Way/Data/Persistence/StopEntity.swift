//
//  StopEntity.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
import SwiftData

@Model
final class StopEntity {

    @Attribute(.unique)
    var id: String

    var latitude: Double
    var longitude: Double

    var nameEnglish: String
    var nameSimplified: String
    var nameTraditional: String
    var regionId: String?
    var districtId: String?

    init(
        id: String,
        latitude: Double,
        longitude: Double,
        nameEnglish: String,
        nameSimplified: String,
        nameTraditional: String,
        regionId: String? = nil,
        districtId: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.nameEnglish = nameEnglish
        self.nameSimplified = nameSimplified
        self.nameTraditional = nameTraditional
        self.regionId = regionId
        self.districtId = districtId
    }
}

extension StopEntity {

    func displayName(
        for language: TransitLanguage
    ) -> String {
        switch language {
        case .english:
            displayNameEnglish
        case .traditionalChinese:
            displayNameTraditional
        case .simplifiedChinese:
            displayNameSimplified
        }
    }

    var displayNameEnglish: String {
        sanitizedStopName(
            nameEnglish
        ).transitDisplayName
    }

    var displayNameSimplified: String {
        sanitizedStopName(
            nameSimplified
        )
    }

    var displayNameTraditional: String {
        sanitizedStopName(
            nameTraditional
        )
    }

    private func sanitizedStopName(
        _ value: String
    ) -> String {

        let breakVariants = [
            "/<br>",
            "/</br>",
            "<br>",
            "</br>",
            "<br/>",
            "<br />"
        ]

        for variant in breakVariants {

            if let range =
                value.range(
                    of: variant,
                    options: .caseInsensitive
                ) {

                let trailing =
                    String(
                        value[
                            range.upperBound...
                        ]
                    )

                let cleanedTrailing =
                    trailing
                        .split {
                            $0.isWhitespace
                        }
                        .joined(
                            separator: " "
                        )

                if !cleanedTrailing.isEmpty {
                    return cleanedTrailing
                }
            }
        }

        return value
            .split {
                $0.isWhitespace
            }
            .joined(
                separator: " "
            )
    }
}
