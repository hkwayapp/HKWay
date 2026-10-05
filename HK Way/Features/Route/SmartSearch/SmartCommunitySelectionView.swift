import SwiftUI

struct SmartCommunitySelectionView: View {
    let districtId: String
    @Binding var community: SmartSearchCommunity?
    @Binding var location: SmartSearchLocation?

    @Environment(\.transitLanguage)
    private var transitLanguage

    @Environment(\.dismiss)
    private var dismiss

    @State private var searchText = ""

    private var communities: [SmartSearchCommunity] {
        let districtCommunities = SmartSearchCommunityCatalog.communities(
            in: districtId
        )

        guard !searchText.isEmpty else {
            return districtCommunities
        }

        return districtCommunities.filter { option in
            option.id.localizedCaseInsensitiveContains(searchText)
                || option.nameEnglish.localizedCaseInsensitiveContains(
                    searchText
                )
                || option.nameTraditional.localizedCaseInsensitiveContains(
                    searchText
                )
                || option.title(for: transitLanguage)
                    .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    community = nil
                    location = nil
                    dismiss()
                } label: {
                    Label(
                        "Use Whole District",
                        systemImage: "square.grid.2x2"
                    )
                    .foregroundStyle(.primary)
                }
            }

            Section("Communities") {
                ForEach(communities) { option in
                    Button {
                        community = option
                        location = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text(option.title(for: transitLanguage))
                                .foregroundStyle(.primary)

                            Spacer()

                            if community?.id == option.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let community {
                Section {
                    NavigationLink {
                        SmartLocationSelectionView(
                            districtId: districtId,
                            community: community,
                            selection: $location
                        )
                    } label: {
                        Label(
                            location?.title(for: transitLanguage)
                                ?? transitLanguage.localized(
                                    "Choose a Specific Stop (Optional)"
                                ),
                            systemImage: "mappin.and.ellipse"
                        )
                        .foregroundStyle(.primary)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label(
                            location == nil
                                ? "Use Whole Community"
                                : "Confirm Selected Stop",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                } header: {
                    Text(community.title(for: transitLanguage))
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Community")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search Communities"
        )
    }
}
