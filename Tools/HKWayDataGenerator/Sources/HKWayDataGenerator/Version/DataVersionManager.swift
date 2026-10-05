//
//  DataVersionManager.swift
//  HK Way
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct DataVersionManager {

    func load(from url: URL) throws -> DataVersion {

        let data = try Data(contentsOf: url)

        return try JSONDecoder()
            .decode(DataVersion.self, from: data)
    }


    func needsUpdate(
        local: DataVersion,
        remote: DataVersion
    ) -> Bool {

        return local.version != remote.version
    }
}
