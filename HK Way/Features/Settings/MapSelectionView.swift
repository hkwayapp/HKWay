//
//  MapSelectionView.swift
//  HK Way
//

import SwiftUI

struct MapSelectionView: View {
    @AppStorage(MapAppPreference.storageKey)
    private var selectedMapApp =
        MapAppPreference.appleMaps.rawValue

    var body: some View {
        List {
            Section {
                ForEach(MapAppPreference.allCases) { mapApp in
                    Button {
                        selectedMapApp = mapApp.rawValue
                    } label: {
                        HStack {
                            Label(
                                mapApp.displayName,
                                systemImage: mapApp == .appleMaps
                                    ? "map"
                                    : "globe"
                            )

                            Spacer()

                            if selectedMapApp == mapApp.rawValue {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } footer: {
                Text(
                    "Used when opening a journey in an external map app."
                )
            }
        }
        .navigationTitle("Map Selection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MapSelectionView()
    }
}
