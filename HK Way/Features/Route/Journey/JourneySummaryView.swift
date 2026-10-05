//
//  JourneySummaryView.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import SwiftUI

struct JourneySummaryView: View {

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.locale)
    private var locale

    let journey: JourneyEntity
    let isCircular: Bool
    let circularDestination: String

    private var orderedStops: [JourneyStopEntity] {
        journey.journeyStops.sorted {
            $0.sequence < $1.sequence
        }
    }

    var body: some View {

        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(
                    destinationText
                )
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        lowerEndpointLabel
                        stopCountLabel
                    }
                } else {
                    HStack(spacing: 8) {
                        lowerEndpointLabel

                        Spacer(minLength: 8)

                        stopCountLabel
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .padding(
            .vertical,
            6
        )
    }

    private var lowerEndpointLabel: some View {
        Text(lowerEndpointText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    private var stopCountLabel: some View {
        Text("\(orderedStops.count) stops")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize(
                horizontal: false,
                vertical: true
            )
    }

    private var lowerEndpointText: String {
        orderedStops.first?
            .stop?
            .displayName(for: transitLanguage)
            ?? (isCircular
                ? circularDestination
                : String(
                    localized: "Origin unavailable",
                    locale: locale
                ))
    }

    private var destinationText: String {
        if isCircular {
            return circularDestination
        }

        return orderedStops.last?
            .stop?
            .displayName(for: transitLanguage)
            ?? String(
                localized: "Destination unavailable",
                locale: locale
            )
    }
}
