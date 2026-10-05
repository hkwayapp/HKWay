//
//  RealOperatorBuilder.swift
//  HK Way
//
//  Created by Ken on 10/8/2026.
//

import Foundation

struct RealOperatorBuilder {

    private let reader = CompanyCodeReader()

    func build() throws -> [Operator] {
        guard let url = Bundle.module.url(
            forResource: "COMPANY_CODE",
            withExtension: "xml"
        ) else {
            throw RealOperatorBuilderError.resourceNotFound
        }

        return try reader.read(from: url)
    }
}

enum RealOperatorBuilderError: Error {
    case resourceNotFound
}
