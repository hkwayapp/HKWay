//
//  DataVersion.swift
//  HK Way
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct DataVersion: Codable {

    let version: String
    let generatedAt: String
    let fareDataUpdatedAt: String?

    init(
        version: String,
        generatedAt: String,
        fareDataUpdatedAt: String? = nil
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.fareDataUpdatedAt = fareDataUpdatedAt
    }
}
