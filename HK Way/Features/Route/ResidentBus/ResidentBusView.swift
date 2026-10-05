import SwiftUI

struct ResidentBusView: View {
    @Environment(\.transitLanguage)
    private var transitLanguage

    var body: some View {
        List {
            Section {
                Label {
                    Text(
                        "Resident bus services are approved for specific residential developments. Availability and passenger eligibility may vary by route."
                    )
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                }
            }

            Section("Official Route Lists") {
                ForEach(ResidentBusRegion.allCases) { region in
                    Link(destination: region.url(for: transitLanguage)) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LocalizedStringKey(region.titleKey))
                                    .foregroundStyle(.primary)

                                Text("View routes and approved service details")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: region.systemImage)
                        }
                    }
                }
            }

            Section {
                Text(
                    "The Transport Department route lists and linked service PDFs are the official source for routes, fares, operating periods, and boarding arrangements. A territory-wide live arrival service is not currently available."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Resident Bus")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum ResidentBusRegion: String, CaseIterable, Identifiable {
    case hongKongIsland
    case kowloon
    case newTerritories

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .hongKongIsland: "Hong Kong Island"
        case .kowloon: "Kowloon"
        case .newTerritories: "New Territories"
        }
    }

    var systemImage: String {
        switch self {
        case .hongKongIsland: "building.2"
        case .kowloon: "building.columns"
        case .newTerritories: "mountain.2"
        }
    }

    func url(for language: TransitLanguage) -> URL {
        let languagePath = switch language {
        case .english: "en"
        case .traditionalChinese: "tc"
        case .simplifiedChinese: "sc"
        }

        let page = switch self {
        case .hongKongIsland: "list_of_approved_rs_hk"
        case .kowloon: "list_of_approved_rs_kln"
        case .newTerritories: "list_of_approved_rs_nt"
        }

        return URL(
            string: "https://www.td.gov.hk/\(languagePath)/transport_in_hong_kong/public_transport/non_franchised/\(page)/index.html"
        )!
    }
}

#Preview {
    NavigationStack {
        ResidentBusView()
    }
}
