//
//  OtherAppsView.swift
//  HK Way
//

import SwiftUI

/// A single catalogue keeps future related apps easy to add without changing the view layout.
private struct RelatedApp: Identifiable {
    let id: String
    let name: (TransitLanguage) -> String
    let description: (TransitLanguage) -> String
    let iconAssetName: String
    let appStoreURL: URL
}

struct OtherAppsView: View {
    @Environment(\.transitLanguage) private var transitLanguage

    // Replace the App Store search URL with the app's canonical product URL once Wei! Guess is live.
    private let apps: [RelatedApp] = [
        RelatedApp(
            id: "wei-guess",
            name: { $0.newsText("Wei! Guess", "喂！估吓啦～", "喂！估吓啦～") },
            description: {
                $0.newsText(
                    "A Cantonese emoji puzzle game",
                    "用 Emoji 猜地道廣東話的小遊戲",
                    "用 Emoji 猜地道粤语的小游戏"
                )
            },
            iconAssetName: "WeiGuessAppIcon",
            appStoreURL: URL(string: "https://apps.apple.com/hk/search?term=Wei%20Guess")!
        )
    ]

    var body: some View {
        List {
            Section {
                ForEach(apps) { app in
                    Link(destination: app.appStoreURL) {
                        appRow(app)
                    }
                    .accessibilityHint(openAppStoreHint)
                }
            } header: {
                Text(sectionTitle)
            } footer: {
                Text(footerText)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func appRow(_ app: RelatedApp) -> some View {
        HStack(spacing: 14) {
            Image(app.iconAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name(transitLanguage))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(app.description(transitLanguage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right.square")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var title: String {
        transitLanguage.newsText("Other Apps", "其他 App", "其他 App")
    }

    private var sectionTitle: String {
        transitLanguage.newsText("Explore", "探索", "探索")
    }

    private var footerText: String {
        transitLanguage.newsText(
            "Tap an app to view or download it in the App Store.",
            "輕觸 App 即可在 App Store 查看或下載。",
            "轻点 App 即可在 App Store 查看或下载。"
        )
    }

    private var openAppStoreHint: String {
        transitLanguage.newsText(
            "Opens the App Store",
            "在 App Store 開啟",
            "在 App Store 打开"
        )
    }
}

#Preview {
    NavigationStack {
        OtherAppsView()
    }
}
