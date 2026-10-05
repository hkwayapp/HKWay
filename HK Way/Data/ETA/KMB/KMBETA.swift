//
//  KMBETA.swift
//  HK Way
//
//  Created by Ken on 13/8/2026.
//

import Foundation

struct KMBETAResponse: Decodable {
    let type: String
    let version: String
    let generatedTimestamp: String
    let data: [KMBETA]

    enum CodingKeys: String, CodingKey {
        case type
        case version
        case generatedTimestamp = "generated_timestamp"
        case data
    }
}

struct KMBETA: Decodable, Identifiable {

    let co: String
    let route: String
    let dir: String?
    let serviceType: Int
    let seq: Int?
    let stop: String?
    let destTC: String
    let destSC: String
    let destEN: String
    let etaSeq: Int
    let eta: String?
    let rmkTC: String
    let rmkSC: String
    let rmkEN: String
    let dataTimestamp: String

    var id: String {
        "\(stop ?? "")|\(route)|\(serviceType)|\(dir ?? "")|\(etaSeq)"
    }

    enum CodingKeys: String, CodingKey {
        case co
        case route
        case dir
        case serviceType = "service_type"
        case seq
        case stop
        case destTC = "dest_tc"
        case destSC = "dest_sc"
        case destEN = "dest_en"
        case etaSeq = "eta_seq"
        case eta
        case rmkTC = "rmk_tc"
        case rmkSC = "rmk_sc"
        case rmkEN = "rmk_en"
        case dataTimestamp = "data_timestamp"
    }
}
