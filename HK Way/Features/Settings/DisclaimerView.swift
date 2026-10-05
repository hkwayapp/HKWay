//
//  DisclaimerView.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import SwiftUI

struct DisclaimerView: View {

    @Environment(\.transitLanguage)
    private var transitLanguage

    private var pageText: (
        title: String,
        thirdPartyData: String,
        referenceOnly: String
    ) {
        (
            transitLanguage.localized(
                "settings.disclaimer.title",
                defaultValue: "Disclaimer"
            ),
            transitLanguage.localized(
                "settings.disclaimer.thirdPartyData",
                defaultValue: "Information provided in this app, including bus routes, arrival times, and location data, is sourced from third-party APIs. While we strive for accuracy, we cannot guarantee the reliability, completeness, or timeliness of this data."
            ),
            transitLanguage.localized(
                "settings.disclaimer.referenceOnly",
                defaultValue: "Please use this information for reference only; service schedules may be subject to change due to traffic or operational conditions. We are not responsible for any direct or indirect losses resulting from the use of this service."
            )
        )
    }

    var body: some View {
        let pageText = pageText

        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 32
            ) {
                Text(pageText.title)
                    .font(.largeTitle.bold())

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {
                    Text(pageText.thirdPartyData)

                    Divider()

                    Text(pageText.referenceOnly)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(20)
                .customInfoCardSurface(
                    showsShadow: false
                )
            }
            .font(.body)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(
            Color(uiColor: .systemGroupedBackground)
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
