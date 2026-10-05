import SwiftUI

private enum SmartSearchRegion: String, CaseIterable, Identifiable {
    case hki
    case kln
    case nt

    var id: Self { self }

    var districtCodes: [String] {
        switch self {
        case .hki: ["A", "B", "C", "D"]
        case .kln: ["E", "F", "G", "H", "J"]
        case .nt: ["K", "L", "M", "N", "P", "Q", "R", "S", "T"]
        }
    }

    func title(for language: TransitLanguage) -> String {
        switch self {
        case .hki: language.localized("Hong Kong Island")
        case .kln: language.localized("Kowloon")
        case .nt: language.localized("New Territories")
        }
    }
}

private struct SmartSearchDistrict: Identifiable {
    let id: String
    let name: String.LocalizationValue

    func title(for language: TransitLanguage) -> String {
        language.localized(name)
    }

    static let all: [SmartSearchDistrict] = [
        .init(id: "A", name: "Central and Western"),
        .init(id: "B", name: "Wan Chai"),
        .init(id: "C", name: "Eastern"),
        .init(id: "D", name: "Southern"),
        .init(id: "E", name: "Yau Tsim Mong"),
        .init(id: "F", name: "Sham Shui Po"),
        .init(id: "G", name: "Kowloon City"),
        .init(id: "H", name: "Wong Tai Sin"),
        .init(id: "J", name: "Kwun Tong"),
        .init(id: "K", name: "Tsuen Wan"),
        .init(id: "L", name: "Tuen Mun"),
        .init(id: "M", name: "Yuen Long"),
        .init(id: "N", name: "North"),
        .init(id: "P", name: "Tai Po"),
        .init(id: "Q", name: "Sai Kung"),
        .init(id: "R", name: "Sha Tin"),
        .init(id: "S", name: "Kwai Tsing"),
        .init(id: "T", name: "Islands")
    ]

    static func district(id: String?) -> SmartSearchDistrict? {
        all.first { $0.id == id }
    }
}

struct SmartRouteSearchView: View {
    @Environment(\.transitLanguage)
    private var transitLanguage

    @State private var originRegion: SmartSearchRegion?
    @State private var originDistrictId: String?
    @State private var originCommunity: SmartSearchCommunity?
    @State private var originLocation: SmartSearchLocation?
    @State private var destinationRegion: SmartSearchRegion?
    @State private var destinationDistrictId: String?
    @State private var destinationCommunity: SmartSearchCommunity?
    @State private var destinationLocation: SmartSearchLocation?
    @State private var isShowingResults = false

    var body: some View {
        List {
            selectionSection(
                title: originTitle,
                systemImage: "circle.circle",
                region: $originRegion,
                districtId: $originDistrictId,
                community: $originCommunity,
                location: $originLocation
            )

            selectionSection(
                title: destinationTitle,
                systemImage: "flag.fill",
                region: $destinationRegion,
                districtId: $destinationDistrictId,
                community: $destinationCommunity,
                location: $destinationLocation
            )

            if let originDistrictId,
               let destinationDistrictId {
                Button {
                    isShowingResults = true
                } label: {
                    Label(showRoutesTitle, systemImage: "bus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: .rect(cornerRadius: 18))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .listRowInsets(
                    EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .navigationDestination(isPresented: $isShowingResults) {
                    SmartRouteResultsView(
                        originDistrictId: originDistrictId,
                        destinationDistrictId: destinationDistrictId,
                        originCommunity: originCommunity,
                        destinationCommunity: destinationCommunity,
                        originLocation: originLocation,
                        destinationLocation: destinationLocation
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(smartSearchTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectionSection(
        title: String,
        systemImage: String,
        region: Binding<SmartSearchRegion?>,
        districtId: Binding<String?>,
        community: Binding<SmartSearchCommunity?>,
        location: Binding<SmartSearchLocation?>
    ) -> some View {
        Section {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    ForEach(SmartSearchRegion.allCases) { option in
                        Button {
                            region.wrappedValue = option
                            districtId.wrappedValue = nil
                            community.wrappedValue = nil
                            location.wrappedValue = nil
                        } label: {
                            Text(option.title(for: transitLanguage))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    region.wrappedValue == option
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(
                                            uiColor:
                                                .secondarySystemGroupedBackground
                                        ),
                                    in: .rect(cornerRadius: 14)
                                )
                                .overlay {
                                    if region.wrappedValue == option {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                Color.accentColor,
                                                lineWidth: 1.5
                                            )
                                    }
                                }
                                .foregroundStyle(
                                    region.wrappedValue == option
                                        ? Color.accentColor
                                        : Color.primary
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let selectedRegion = region.wrappedValue {
                    Divider()

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 145))],
                        spacing: 10
                    ) {
                        ForEach(
                            selectedRegion.districtCodes,
                            id: \.self
                        ) { code in
                            if let district = SmartSearchDistrict.district(
                                id: code
                            ) {
                                Button {
                                    districtId.wrappedValue = code
                                    community.wrappedValue = nil
                                    location.wrappedValue = nil
                                } label: {
                                    Text(district.title(for: transitLanguage))
                                        .font(.body.weight(.medium))
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: 48
                                        )
                                        .background(
                                            districtId.wrappedValue == code
                                                ? Color.accentColor.opacity(0.18)
                                                : Color(
                                                    uiColor:
                                                        .secondarySystemGroupedBackground
                                                ),
                                            in: .rect(cornerRadius: 14)
                                        )
                                        .overlay {
                                            if districtId.wrappedValue == code {
                                                RoundedRectangle(
                                                    cornerRadius: 14
                                                )
                                                .stroke(
                                                    Color.accentColor,
                                                    lineWidth: 1.5
                                                )
                                            }
                                        }
                                        .foregroundStyle(
                                            districtId.wrappedValue == code
                                                ? Color.accentColor
                                                : Color.primary
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if let selectedDistrictId = districtId.wrappedValue {
                    Divider()

                    NavigationLink {
                        SmartCommunitySelectionView(
                            districtId: selectedDistrictId,
                            community: community,
                            location: location
                        )
                    } label: {
                        Label(
                            location.wrappedValue?.title(
                                for: transitLanguage
                            ) ?? community.wrappedValue?.title(
                                for: transitLanguage
                            ) ?? transitLanguage.localized(
                                "Choose a Community (Optional)"
                            ),
                            systemImage: "building.2"
                        )
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 13)
                        .padding(.horizontal, 14)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: .rect(cornerRadius: 14)
                        )
                    }
                    .id(
                        "\(selectedDistrictId)|\(community.wrappedValue?.id ?? "all")"
                    )
                }
            }
            .padding(16)
            .background(
                Color(uiColor: .systemBackground),
                in: .rect(cornerRadius: 22)
            )
            .listRowInsets(
                EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var smartSearchTitle: String {
        transitLanguage.localized("Smart Route Search")
    }

    private var originTitle: String {
        transitLanguage.localized("Origin")
    }

    private var destinationTitle: String {
        transitLanguage.localized("Destination")
    }

    private var showRoutesTitle: String {
        transitLanguage.localized("Show Routes")
    }
}
