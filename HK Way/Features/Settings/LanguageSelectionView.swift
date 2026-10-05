//
//  LanguageSelectionView.swift
//  HK Way
//
//  Created by Ken on 14/8/2026.
//

import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.dismiss)
    private var dismiss

    @AppStorage("appLanguage")
    private var selectedLanguage = TransitLanguage.traditionalChinese.rawValue

    var body: some View {
        Form {
            Section(
                footer: Text(
                    "Choose your preferred language for the entire app."
                )
            ) {
                ForEach(TransitLanguage.allCases) { language in
                    Button(action: {
                        selectedLanguage = language.rawValue
                        dismiss()
                    }) {
                        HStack {
                            Text(language.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedLanguage == language.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.primary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Language Selection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
}
