//
//  CTBETA.swift
//  HK Way
//
//  Created by Ken on 16/8/2026.
//

import Foundation

struct CTBETA: Codable {

    let companyId: String
    let route: String
    let direction: String?
    let sequence: Int?

    let destinationTraditional: String
    let destinationSimplified: String
    let destinationEnglish: String

    let eta: String?
    let remarkTraditional: String
    let remarkSimplified: String
    let remarkEnglish: String

    enum CodingKeys: String, CodingKey {

        case companyId = "co"
        case route
        case direction = "dir"
        case sequence = "eta_seq"

        case destinationTraditional = "dest_tc"
        case destinationSimplified = "dest_sc"
        case destinationEnglish = "dest_en"

        case eta

        case remarkTraditional = "rmk_tc"
        case remarkSimplified = "rmk_sc"
        case remarkEnglish = "rmk_en"
    }
}
