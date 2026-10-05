//
//  DatasetVersionStore.swift
//  HK Way
//
//  Created by Ken on 10/8/2026.
//

import Foundation

struct DatasetVersionStore {
    
    private let key = "installedDatasetVersion"
    private let fareDataUpdatedAtKey = "installedFareDataUpdatedAt"
    
    var installedVersion: String? {
        UserDefaults.standard.string(forKey: key)
    }

    var fareDataUpdatedAt: String? {
        UserDefaults.standard.string(
            forKey: fareDataUpdatedAtKey
        )
    }
    
    func save(
        version: String,
        fareDataUpdatedAt: String? = nil
    ) {
        UserDefaults.standard.set(version, forKey: key)

        if let fareDataUpdatedAt {
            UserDefaults.standard.set(
                fareDataUpdatedAt,
                forKey: fareDataUpdatedAtKey
            )
        } else {
            UserDefaults.standard.removeObject(
                forKey: fareDataUpdatedAtKey
            )
        }
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(
            forKey: fareDataUpdatedAtKey
        )
    }
    
}
