import Foundation

enum ExternalLinkLocalizer {
    static func url(_ url: URL, for language: TransitLanguage) -> URL {
        guard url.scheme == "https", let host = url.host?.lowercased() else {
            return url
        }

        if host == "registration.tszshan.org" {
            return replacingRegistrationLocale(in: url, language: language)
        }

        if host == "kaitaksportspark.com.hk" || host == "www.kaitaksportspark.com.hk" {
            return replacingKaiTakLocale(in: url, language: language)
        }

        let languageFamily: LanguageFamily?
        switch host {
        case "data.gov.hk", "www.data.gov.hk":
            languageFamily = .dataGov
        case "td.gov.hk", "www.td.gov.hk":
            languageFamily = .standard
        case "tszshan.org", "www.tszshan.org":
            languageFamily = .tszShan
        case "mtr.com.hk", "www.mtr.com.hk":
            languageFamily = .mtr
        case "np360.com.hk", "www.np360.com.hk",
             "webstore.np360.com.hk",
             "oceanpark.com.hk", "www.oceanpark.com.hk",
             "waterworld.oceanpark.com.hk",
             "wetlandpark.gov.hk", "www.wetlandpark.gov.hk",
             "onebus.hk", "www.onebus.hk",
             "hzmb.gov.hk", "www.hzmb.gov.hk":
            languageFamily = .standard
        default:
            languageFamily = nil
        }

        guard let languageFamily else { return url }
        return replacingLanguagePath(
            in: url,
            with: languageFamily.pathComponent(for: language)
        )
    }

    private static func replacingKaiTakLocale(
        in url: URL,
        language: TransitLanguage
    ) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var pathComponents = components.path.split(
            separator: "/",
            omittingEmptySubsequences: true
        ).map(String.init)
        if let first = pathComponents.first, first == "tc" || first == "sc" {
            pathComponents.removeFirst()
        }
        switch language {
        case .english:
            break
        case .traditionalChinese:
            pathComponents.insert("tc", at: 0)
        case .simplifiedChinese:
            pathComponents.insert("sc", at: 0)
        }
        components.path = "/" + pathComponents.joined(separator: "/")
        return components.url ?? url
    }

    private static func replacingLanguagePath(
        in url: URL,
        with replacement: String
    ) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var pathComponents = components.path.split(
            separator: "/",
            omittingEmptySubsequences: true
        ).map(String.init)
        let recognized = [
            "en", "tc", "sc", "ch", "zh-hk", "zh-cn",
            "en-data", "tc-data", "sc-data", "EN", "TC", "SC"
        ]
        guard let index = pathComponents.firstIndex(where: recognized.contains) else {
            return url
        }

        let current = pathComponents[index]
        pathComponents[index] = current == current.uppercased()
            ? replacement.uppercased()
            : replacement
        components.path = "/" + pathComponents.joined(separator: "/")
        return components.url ?? url
    }

    private static func replacingRegistrationLocale(
        in url: URL,
        language: TransitLanguage
    ) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let locale = switch language {
        case .english: "en_US"
        case .traditionalChinese: "zh_HK"
        case .simplifiedChinese: "zh_CN"
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "locale" }
        queryItems.append(URLQueryItem(name: "locale", value: locale))
        components.queryItems = queryItems
        return components.url ?? url
    }

    private enum LanguageFamily {
        case standard
        case dataGov
        case tszShan
        case mtr

        func pathComponent(for language: TransitLanguage) -> String {
            switch (self, language) {
            case (.standard, .english): "en"
            case (.standard, .traditionalChinese): "tc"
            case (.standard, .simplifiedChinese): "sc"
            case (.dataGov, .english): "en-data"
            case (.dataGov, .traditionalChinese): "tc-data"
            case (.dataGov, .simplifiedChinese): "sc-data"
            case (.tszShan, .english): "en"
            case (.tszShan, .traditionalChinese): "zh-hk"
            case (.tszShan, .simplifiedChinese): "zh-cn"
            case (.mtr, .english): "en"
            case (.mtr, .traditionalChinese), (.mtr, .simplifiedChinese): "ch"
            }
        }
    }
}
