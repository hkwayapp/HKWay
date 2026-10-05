import SwiftUI

enum TransitLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case traditionalChinese = "繁體中文"
    case simplifiedChinese = "简体中文"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var locale: Locale {
        switch self {
        case .english:
            Locale(identifier: "en")
        case .traditionalChinese:
            Locale(identifier: "zh-Hant-HK")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans-HK")
        }
    }

    init(preferenceValue: String) {
        self = Self(rawValue: preferenceValue) ?? .english
    }

    func localized(
        _ resource: String.LocalizationValue
    ) -> String {
        String(
            localized: resource,
            bundle: localizationBundle,
            locale: locale
        )
    }

    func localized(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> String {
        String(
            localized: key,
            defaultValue: defaultValue,
            bundle: localizationBundle,
            locale: locale
        )
    }

    private var localizationBundle: Bundle {
        guard
            let path = Bundle.main.path(
                forResource: locale.identifier,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return .main
        }

        return bundle
    }
}

private struct TransitLanguageKey: EnvironmentKey {
    static let defaultValue = TransitLanguage.english
}

extension EnvironmentValues {
    var transitLanguage: TransitLanguage {
        get { self[TransitLanguageKey.self] }
        set { self[TransitLanguageKey.self] = newValue }
    }
}
