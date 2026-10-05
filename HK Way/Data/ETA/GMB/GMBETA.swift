//
//  GMBETA.swift
//  HK Way
//

import Foundation

struct GMBETA: Codable {

    let sequence: Int
    let timestamp: String?
    let remarkTraditional: String
    let remarkSimplified: String
    let remarkEnglish: String

    enum CodingKeys: String, CodingKey {
        case sequence = "eta_seq"
        case timestamp
        case remarkTraditional = "remarks_tc"
        case remarkSimplified = "remarks_sc"
        case remarkEnglish = "remarks_en"
    }
}
