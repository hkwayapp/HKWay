//
//  DataSourcesView.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import SwiftUI

struct DataSourcesView: View {

    @Environment(\.transitLanguage)
    private var transitLanguage

    private var pageText: (
        title: String,
        referenceOnly: String,
        providerDescription: String,
        visitLink: String
    ) {
        (
            transitLanguage.localized(
                "settings.dataSources.title",
                defaultValue: "Data Sources"
            ),
            transitLanguage.localized(
                "settings.dataSources.referenceOnly",
                defaultValue: "Please use this information for reference only; service schedules may be subject to change due to traffic or operational conditions. We are not responsible for any direct or indirect losses resulting from the use of this service."
            ),
            transitLanguage.localized(
                "settings.dataSources.providerDescription",
                defaultValue: "Transit data provided in this app is retrieved via the data.gov.hk API. While we strive to ensure the accuracy of the information displayed, we cannot guarantee the reliability, completeness, or timeliness of these data feeds."
            ),
            transitLanguage.localized(
                "settings.dataSources.visitLink",
                defaultValue: "Visit data.gov.hk"
            )
        )
    }

    private var fareSourceText: (
        title: String,
        description: String,
        updated: String,
        link: String
    ) {
        (
            transitLanguage.localized(
                "settings.dataSources.fareTitle",
                defaultValue: "Fare Data"
            ),
            transitLanguage.localized(
                "settings.dataSources.fareDescription",
                defaultValue: "Full, sectional, and boarding fares are provided by the Hong Kong Transport Department through DATA.GOV.HK."
            ),
            transitLanguage.localized(
                "settings.dataSources.fareUpdated",
                defaultValue: "Fare data updated"
            ),
            transitLanguage.localized(
                "settings.dataSources.fareLink",
                defaultValue: "View Transport Department fare data"
            )
        )
    }

    private var fareDataUpdatedDate: String? {
        DatasetVersionStore().fareDataUpdatedAt.map {
            String($0.prefix(10))
        }
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

                informationCard {
                    Text(pageText.referenceOnly)
                }

                informationCard {
                    VStack(
                        alignment: .leading,
                        spacing: 24
                    ) {
                        Text(pageText.providerDescription)

                        Divider()

                        Link(
                            pageText.visitLink,
                            destination: URL(
                                string: "https://data.gov.hk"
                            )!
                        )
                    }
                }

                informationCard {
                    let text = fareSourceText

                    VStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        Label(
                            text.title,
                            systemImage: "dollarsign.circle"
                        )
                        .font(.headline)

                        Text(text.description)

                        if let fareDataUpdatedDate {
                            Text(
                                "\(text.updated): " +
                                    fareDataUpdatedDate
                            )
                            .foregroundStyle(.secondary)
                        }

                        Link(
                            text.link,
                            destination: URL(
                                string: "https://data.gov.hk/en-data/dataset/hk-td-tis_14-routes-fares-xml"
                            )!
                        )
                    }
                }

                informationCard {
                    VStack(
                        alignment: .leading,
                        spacing: 14
                    ) {
                        Label(
                            "Community Boundaries",
                            systemImage: "map"
                        )
                        .font(.headline)

                        Text(
                            "Smart Search local areas use the detailed 2019 District Council constituency boundaries published by the Electoral Affairs Commission. These historical boundaries are used only as familiar geographic area names."
                        )

                        Link(
                            "View Electoral Affairs Commission boundary data",
                            destination: URL(
                                string: "https://data.gov.hk/en-data/dataset/eac-eacpsi01-dcca-boundaries-2019"
                            )!
                        )
                    }
                }
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

    private func informationCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(20)
            .customInfoCardSurface(
                showsShadow: false
            )
    }
}
