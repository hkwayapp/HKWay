//
//  SettingsView.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import SwiftUI
import UserMessagingPlatform

struct SettingsView: View {
    @Environment(\.transitLanguage)
    private var transitLanguage

    @AppStorage("appLanguage")
    private var selectedLanguage = TransitLanguage.traditionalChinese.rawValue

    @AppStorage(AppAppearance.storageKey)
    private var selectedAppearance = AppAppearance.system.rawValue

    @AppStorage(OperatorSelectionPreference.storageKey)
    private var selectedOperatorIdsValue = ""

    @AppStorage(DefaultAppTab.storageKey)
    private var defaultAppTab = DefaultAppTab.nearby.rawValue

    @AppStorage(MapAppPreference.storageKey)
    private var selectedMapApp =
        MapAppPreference.appleMaps.rawValue

    @AppStorage("favoriteRouteIds")
    private var favoriteRouteIdsValue = ""

    @AppStorage("favoriteStopIds")
    private var favoriteStopIdsValue = ""

    @State
    private var showsCleanFavoritesConfirmation = false

    @State
    private var showsSetupAssistant = false

    private var operatorSelectionSummary: String {
        let selectedIds = OperatorSelectionPreference.ids(
            from: selectedOperatorIdsValue
        )

        return selectedIds.isEmpty
            ? "All Operators"
            : selectedIds.sorted().map {
                CustomBadgeView.displayText(
                    for: $0,
                    language: transitLanguage
                )
            }
            .joined(separator: ", ")
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                NavigationSplitView {
                    settingsList
                        .navigationSplitViewColumnWidth(
                            min: 240,
                            ideal: 280,
                            max: 320
                        )
                } detail: {
                    ContentUnavailableView(
                        settingsPlaceholderTitle,
                        systemImage: "gearshape",
                        description: Text(settingsPlaceholderDescription)
                    )
                }
            } else {
                settingsList
            }
        }
        .fullScreenCover(isPresented: $showsSetupAssistant) {
            FirstRunSetupView(
                isDatasetReady: true,
                onComplete: {
                    showsSetupAssistant = false
                },
                onCancel: {
                    showsSetupAssistant = false
                }
            )
            .environment(\.transitLanguage, transitLanguage)
            .environment(\.locale, transitLanguage.locale)
        }
        .alert(
            "Clean Favorite Data?",
            isPresented: $showsCleanFavoritesConfirmation
        ) {
            Button("No", role: .cancel) {}

            Button("Yes", role: .destructive) {
                favoriteRouteIdsValue = ""
                favoriteStopIdsValue = ""
            }
        } message: {
            Text(
                "This will remove all favorite routes and stops."
            )
        }
    }

    private var settingsList: some View {
        List {
                Section(header: Text("Preference")) {
                    Button {
                        showsSetupAssistant = true
                    } label: {
                        Label(
                            setupAssistantTitle,
                            systemImage: "wand.and.stars"
                        )
                        .foregroundStyle(.primary)
                    }

                    NavigationLink(destination: LanguageSelectionView()) {
                        HStack {
                            Label("Language", systemImage: "globe")
                            if !isPad {
                                Spacer()
                                Text(
                                    TransitLanguage(
                                        preferenceValue: selectedLanguage
                                    )
                                    .displayName
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink(
                        destination: AppearanceSelectionView()
                    ) {
                        HStack {
                            Label(
                                "Appearance",
                                systemImage: "circle.lefthalf.filled"
                            )

                            if !isPad {
                                Spacer()

                                Text(
                                    AppAppearance(
                                        rawValue: selectedAppearance
                                    )?.displayName
                                        ?? AppAppearance.system.displayName
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: OperatorSelectionView()) {
                        HStack {
                            Label("Operators", systemImage: "bus")
                            if !isPad {
                                Spacer()
                                Text(
                                    LocalizedStringKey(
                                        operatorSelectionSummary
                                    )
                                )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }

                    NavigationLink(destination: DefaultTabSelectionView()) {
                        HStack {
                            Label(
                                "Default Tab",
                                systemImage: "rectangle.on.rectangle"
                            )

                            if !isPad {
                                Spacer()

                                Text(
                                    LocalizedStringKey(
                                        DefaultAppTab(
                                            rawValue: defaultAppTab
                                        )?.displayName
                                            ?? DefaultAppTab.nearby.displayName
                                    )
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink(destination: MapSelectionView()) {
                        HStack {
                            Label(
                                "Map Selection",
                                systemImage: "map"
                            )

                            if !isPad {
                                Spacer()

                                Text(
                                    MapAppPreference(
                                        rawValue: selectedMapApp
                                    )?.displayName
                                        ?? MapAppPreference.appleMaps.displayName
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("Data Update")) {
                    NavigationLink(destination: DataUpdateView()) {
                        Label("Dataset", systemImage: "cylinder.split.1x2")
                    }

                    Button(role: .destructive) {
                        showsCleanFavoritesConfirmation = true
                    } label: {
                        Label(
                            "Clean Favorite Data",
                            systemImage: "trash"
                        )
                    }
                }

                Section(header: Text("Support")) {
                    NavigationLink(destination: SupportView()) {
                        Label("Support HK Way", systemImage: "heart.fill")
                    }
                }

                if ConsentInformation.shared.privacyOptionsRequirementStatus == .required {
                    Section(header: Text(advertisingPrivacySectionTitle)) {
                        Button {
                            Task {
                                try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
                            }
                        } label: {
                            Label(
                                advertisingPrivacyTitle,
                                systemImage: "hand.raised.fill"
                            )
                            .foregroundStyle(.primary)
                        }
                    }
                }

                
                Section(header: Text("About")) {
                    HStack {
                            Label("Version", systemImage: "info.circle")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                    
                    NavigationLink(destination: DataSourcesView()) {
                        Label("Data Sources", systemImage: "cylinder.split.1x2")
                    }
                    NavigationLink(destination: DisclaimerView()) {
                        Label("Disclaimer", systemImage: "doc.text")
                    }
                }
        }
        .navigationTitle("Settings")
        .tint(.primary)
    }

    private var settingsPlaceholderTitle: String {
        switch transitLanguage {
        case .english: "Settings"
        case .traditionalChinese: "設定"
        case .simplifiedChinese: "设置"
        }
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var settingsPlaceholderDescription: String {
        switch transitLanguage {
        case .english: "Choose an item from the menu."
        case .traditionalChinese: "請從選單選擇一個設定項目。"
        case .simplifiedChinese: "请从菜单选择一个设置项目。"
        }
    }

    private var setupAssistantTitle: String {
        switch transitLanguage {
        case .english:
            "Setup Assistant"
        case .traditionalChinese:
            "設定助理"
        case .simplifiedChinese:
            "设置助理"
        }
    }

    private var advertisingPrivacySectionTitle: String {
        switch transitLanguage {
        case .english: "Privacy"
        case .traditionalChinese: "私隱"
        case .simplifiedChinese: "隐私"
        }
    }

    private var advertisingPrivacyTitle: String {
        switch transitLanguage {
        case .english: "Advertising Privacy Options"
        case .traditionalChinese: "廣告私隱選項"
        case .simplifiedChinese: "广告隐私选项"
        }
    }

}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(PurchaseManager())
}
