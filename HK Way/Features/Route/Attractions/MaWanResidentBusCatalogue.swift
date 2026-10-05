import Foundation

struct MaWanResidentBusRoute: Identifiable {
    let number: String
    let destination: String
    let documentFileName: String

    var id: String { number }

    var officialURL: URL {
        URL(string: "https://www.td.gov.hk/filemanager/en/content_4796/TNTW/\(documentFileName)")!
    }
}

enum MaWanResidentBusCatalogue {
    static let routes: [MaWanResidentBusRoute] = [
        .init(number: "NR330", destination: "Tsing Yi Station", documentFileName: "NR330_20240101_r.pdf"),
        .init(number: "NR331", destination: "Tsuen Wan (Circular)", documentFileName: "NR331_20241215.pdf"),
        .init(number: "NR332", destination: "Kwai Fong", documentFileName: "NR332_20250301_r.pdf"),
        .init(number: "NR334", destination: "Hong Kong International Airport (Circular)", documentFileName: "NR334_20240201_r.pdf"),
        .init(number: "NR338", destination: "Central (Overnight Circular)", documentFileName: "NR338_20240101_r.pdf"),
        .init(number: "NR338S", destination: "Central (Circular)", documentFileName: "NR338S_20250814.pdf")
    ]
}
