//
//  DefaultTabSelectionView.swift
//  HK Way
//

import SwiftUI

enum DefaultAppTab: String, CaseIterable, Identifiable {
    static let storageKey = "defaultAppTab"

    case favorites
    case nearby

    var id: Self { self }

    var displayName: String {
        switch self {
        case .favorites:
            "Favorites"
        case .nearby:
            "Nearby"
        }
    }

    var systemImage: String {
        switch self {
        case .favorites:
            "bookmark"
        case .nearby:
            "location.fill"
        }
    }

    var appTab: AppTab {
        switch self {
        case .favorites:
            .favorites
        case .nearby:
            .nearby
        }
    }
}

struct DefaultTabSelectionView: View {
    @AppStorage(DefaultAppTab.storageKey)
    private var defaultAppTab = DefaultAppTab.nearby.rawValue

    var body: some View {
        Form {
            Section {
                ForEach(DefaultAppTab.allCases) { tab in
                    Button {
                        defaultAppTab = tab.rawValue
                    } label: {
                        HStack {
                            Label(
                                LocalizedStringKey(tab.displayName),
                                systemImage: tab.systemImage
                            )
                            .foregroundStyle(.primary)

                            Spacer()

                            if defaultAppTab == tab.rawValue {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(
                    "Choose the tab shown when HK Way opens."
                )
            }
        }
        .navigationTitle("Default Tab")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.primary)
    }
}

#Preview {
    NavigationStack {
        DefaultTabSelectionView()
    }
}
