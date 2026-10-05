import Foundation

@main
enum ExternalLinkLocalizerChecks {
    static func main() {
        check(
            "https://data.gov.hk/en-data/dataset/example",
            .traditionalChinese,
            "https://data.gov.hk/tc-data/dataset/example"
        )
        check(
            "https://www.td.gov.hk/en/transport/index.html#section",
            .simplifiedChinese,
            "https://www.td.gov.hk/sc/transport/index.html#section"
        )
        check(
            "https://www.tszshan.org/home/new/en/visit.php#transaction",
            .traditionalChinese,
            "https://www.tszshan.org/home/new/zh-hk/visit.php#transaction"
        )
        check(
            "https://registration.tszshan.org/?locale=en_US",
            .simplifiedChinese,
            "https://registration.tszshan.org/?locale=zh_CN"
        )
        check(
            "https://www.mtr.com.hk/en/customer/services/routemap_index.html",
            .traditionalChinese,
            "https://www.mtr.com.hk/ch/customer/services/routemap_index.html"
        )
        check(
            "https://www.kaitaksportspark.com.hk/events-tickets",
            .traditionalChinese,
            "https://www.kaitaksportspark.com.hk/tc/events-tickets"
        )
        check(
            "https://www.kaitaksportspark.com.hk/tc/getting-here",
            .english,
            "https://www.kaitaksportspark.com.hk/getting-here"
        )
        check(
            "https://www.onebus.hk/en/home",
            .simplifiedChinese,
            "https://www.onebus.hk/sc/home"
        )
        check(
            "https://www.hzmb.gov.hk/en/cross-boundary.html",
            .traditionalChinese,
            "https://www.hzmb.gov.hk/tc/cross-boundary.html"
        )
        check(
            "https://example.com/en/page",
            .traditionalChinese,
            "https://example.com/en/page"
        )
        print("External link localization checks passed")
    }

    private static func check(
        _ input: String,
        _ language: TransitLanguage,
        _ expected: String
    ) {
        let result = ExternalLinkLocalizer.url(URL(string: input)!, for: language)
        precondition(result.absoluteString == expected, "\(result) != \(expected)")
    }
}
