import Foundation
import Observation

struct TVTrafficNotice: Identifiable, Equatable, Sendable {
    let id: String
    let heading: String
    let location: String
    let content: String
    let announcedAt: Date?
}

@MainActor
@Observable
final class TVTrafficNewsStore {
    private(set) var notices: [TVTrafficNotice] = []
    private(set) var isLoading = false
    private(set) var hasError = false
    private(set) var updatedAt: Date?

    func refresh(language: TVLanguage) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let languagePath = switch language {
        case .english: "en"
        case .traditionalChinese: "tc"
        case .simplifiedChinese: "sc"
        }
        guard let url = URL(
            string: "https://resource.data.one.gov.hk/td/\(languagePath)/specialtrafficnews.xml"
        ) else {
            hasError = true
            return
        }

        do {
            var request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            request.setValue("application/xml", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            notices = try TVLegacyTrafficNewsParser(language: language)
                .parse(data)
                .sorted {
                    ($0.announcedAt ?? .distantPast)
                        > ($1.announcedAt ?? .distantPast)
                }
            updatedAt = .now
            hasError = false
        } catch {
            hasError = true
        }
    }
}

private final class TVLegacyTrafficNewsParser: NSObject, XMLParserDelegate {
    private let language: TVLanguage
    private var currentText = ""
    private var fields: [String: String] = [:]
    private var results: [TVTrafficNotice] = []

    init(language: TVLanguage) {
        self.language = language
    }

    func parse(_ data: Data) throws -> [TVTrafficNotice] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return results
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        if elementName == "message" { fields = [:] }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if elementName == "message" {
            let contentKey = language == .english ? "EngText" : "ChinText"
            let shortKey = language == .english ? "EngShort" : "ChinShort"
            let content = fields[contentKey] ?? fields[shortKey] ?? ""
            guard !content.isEmpty else { return }

            results.append(
                TVTrafficNotice(
                    id: "data-gov-hk-\(fields["msgID"] ?? UUID().uuidString)",
                    heading: language.text(
                        "Traffic Update",
                        "交通消息",
                        "交通消息"
                    ),
                    location: "",
                    content: content,
                    announcedAt: Self.parseDate(fields["ReferenceDate"])
                )
            )
        } else if !value.isEmpty {
            fields[elementName] = value
        }
        currentText = ""
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats: [(String, String)] = [
            ("zh_HK", "yyyy/M/d a hh:mm:ss"),
            ("en_US_POSIX", "yyyy/M/d hh:mm:ss a"),
            ("en_US_POSIX", "yyyy/M/d HH:mm:ss")
        ]

        for (localeID, format) in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: localeID)
            formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}

private final class TVTrafficNewsParser: NSObject, XMLParserDelegate {
    private let language: TVLanguage
    private var currentElement = ""
    private var currentText = ""
    private var fields: [String: String] = [:]
    private var results: [TVTrafficNotice] = []

    init(language: TVLanguage) {
        self.language = language
    }

    func parse(_ data: Data) throws -> [TVTrafficNotice] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return results
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
        if elementName == "message" { fields = [:] }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "message" {
            let suffix = language == .english ? "EN" : "CN"
            let id = fields["INCIDENT_NUMBER"] ?? fields["ID"] ?? UUID().uuidString
            let notice = TVTrafficNotice(
                id: id,
                heading: fields["INCIDENT_HEADING_\(suffix)"] ?? "",
                location: fields["LOCATION_\(suffix)"] ?? "",
                content: fields["CONTENT_\(suffix)"] ?? "",
                announcedAt: Self.parseDate(fields["ANNOUNCEMENT_DATE"])
            )
            if !notice.content.isEmpty { results.append(notice) }
        } else if !value.isEmpty {
            fields[elementName] = value
        }
        currentElement = ""
        currentText = ""
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value)
    }
}
