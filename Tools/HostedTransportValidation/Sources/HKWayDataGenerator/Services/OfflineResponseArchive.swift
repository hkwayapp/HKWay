import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OfflineResponseArchive: Sendable {
    struct Entry: Decodable, Sendable {
        let file: String
        let status: Int
    }

    let directory: URL
    let entries: [String: Entry]

    init(directory: URL) throws {
        self.directory = directory.resolvingSymlinksInPath()
        entries = try JSONDecoder().decode([String: Entry].self, from:
            Data(contentsOf: directory.appendingPathComponent("responses.json")))
    }

    func response(for url: URL) throws -> (Data, URLResponse) {
        guard let entry = entries[url.absoluteString] else {
            throw DatasetPreservationError.conflict("Missing captured GET response for \(url.absoluteString).")
        }
        let path = directory.appendingPathComponent(entry.file).resolvingSymlinksInPath()
        guard path.path.hasPrefix(directory.path + "/"), (200..<300).contains(entry.status),
              let response = HTTPURLResponse(url: url, statusCode: entry.status, httpVersion: nil, headerFields: nil) else {
            throw DatasetPreservationError.conflict("Invalid or unsuccessful captured response for \(url.absoluteString).")
        }
        let data = try Data(contentsOf: path)
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }
        return (data, response)
    }
}

enum OfflineTDResources {
    @TaskLocal static var directory: URL?

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        guard let directory else { return Bundle.module.url(forResource: name, withExtension: ext) }
        let file = directory.appendingPathComponent(name).appendingPathExtension(ext)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
}
