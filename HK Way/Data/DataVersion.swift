//
//  DataVersion.swift
//  HK Way
//
//  Created by Ken on 10/8/2026.
//

import Foundation
 
struct DataVersion: Codable {
    let version: String
    let generatedAt: String
    let fareDataUpdatedAt: String?
}
