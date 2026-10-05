//
//  DatasetStorage.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct DatasetStorage {

    nonisolated init() {}

    nonisolated func installedDatasetDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupport
            .appendingPathComponent("TransitGoDataset")
    }

    nonisolated func fileURL(for file: DatasetFile) throws -> URL {
        try installedDatasetDirectory()
            .appendingPathComponent(file.rawValue)
    }
}
