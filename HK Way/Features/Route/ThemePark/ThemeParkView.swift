import SwiftUI

enum ThemeParkDestination: String, CaseIterable, Identifiable {
    case disneyland
    case oceanPark
    case waterWorld
    case wetlandPark

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .disneyland: "Disneyland"
        case .oceanPark: "Hong Kong Ocean Park"
        case .waterWorld: "Water World Ocean Park Hong Kong"
        case .wetlandPark: "Hong Kong Wetland Park"
        }
    }

    var systemImage: String {
        switch self {
        case .disneyland: "sparkles"
        case .oceanPark: "fish.fill"
        case .waterWorld: "water.waves"
        case .wetlandPark: "leaf.fill"
        }
    }

    func title(for language: TransitLanguage) -> String {
        switch self {
        case .disneyland: language.localized("Disneyland")
        case .oceanPark: language.localized("Hong Kong Ocean Park")
        case .waterWorld: language.localized("Water World Ocean Park Hong Kong")
        case .wetlandPark: language.localized("Hong Kong Wetland Park")
        }
    }

    func matches(stop: StopEntity) -> Bool {
        let name = stop.nameEnglish.lowercased()

        switch self {
        case .disneyland:
            return name.contains("disneyland")
        case .oceanPark:
            return name.contains("ocean park")
                && !name.contains("ocean park road")
                && !name.contains("water world")
        case .waterWorld:
            return name.contains("water world")
        case .wetlandPark:
            return name.contains("wetland park")
        }
    }
}

struct ThemeParkView: View {
    @Environment(\.transitLanguage)
    private var transitLanguage

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ThemeParkDestination.allCases) { destination in
                        NavigationLink {
                            ThemeParkDetailView(
                                destination: destination
                            )
                        } label: {
                            CustomInfoCardView(title: "") {
                                VStack(spacing: 8) {
                                    Image(systemName: destination.systemImage)
                                        .font(.title2)

                                    Text(
                                        LocalizedStringKey(
                                            destination.titleKey
                                        )
                                    )
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Label(
                    "Routes shown may travel directly to the theme park or serve it as an intermediate stop.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .padding()
        }
        .navigationTitle(
            transitLanguage.localized("Theme Park Routes")
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ThemeParkView()
    }
}
