import Foundation

struct KMBPublicStopCodeReader {
    private struct Payload: Decodable {
        let codes: [String: String]
    }

    func read() throws -> [String: String] {
        guard let url = Bundle.module.url(
            forResource: "kmb_public_stop_codes",
            withExtension: "json"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let payload = try JSONDecoder().decode(
            Payload.self,
            from: Data(contentsOf: url)
        )

        return Dictionary(
            uniqueKeysWithValues: payload.codes.map {
                ($0.key.uppercased(), $0.value)
            }
        )
    }
}
