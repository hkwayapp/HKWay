import Foundation

struct SectionFareReader {

    func read() throws -> [String: [SectionFareTier]] {
        guard let url = Bundle.module.url(
            forResource: "section_fares",
            withExtension: "json"
        ) else {
            throw SectionFareReaderError.resourceNotFound
        }

        return try JSONDecoder().decode(
            [String: [SectionFareTier]].self,
            from: Data(contentsOf: url)
        )
    }
}

enum SectionFareReaderError: Error {
    case resourceNotFound
}
