//
//  SwiftDataImportVersionStore.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct SwiftDataImportVersionStore {

    private let key = "importedDatasetVersion"

    var importedVersion: String? {
        UserDefaults.standard.string(forKey: key)
    }

    func save(version: String) {
        UserDefaults.standard.set(
            version,
            forKey: key
        )
    }

    func clear() {
        UserDefaults.standard.removeObject(
            forKey: key
        )
    }
}
