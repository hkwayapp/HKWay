//
//  RealRouteBuilder.swift
//  HK Way
//
//  Created by Ken on 9/8/2026.
//

import Foundation

struct RealRouteBuilder {

    private let reader = RouteBusXMLReader()

    func build() throws -> [Route] {
        let url = try resourceURL()

        let records = try reader.read(from: url)

        return records.map { record in
            Route(
                id: record.routeID,
                number: record.number,
                operatorIds: [record.companyCode],

                originEnglish: record.originEnglish,
                originTraditional: record.originTraditional,
                originSimplified: record.originSimplified,

                destinationEnglish: record.destinationEnglish,
                destinationTraditional: record.destinationTraditional,
                destinationSimplified: record.destinationSimplified
            )
        }
    }

    private func resourceURL() throws -> URL {
        guard let url = Bundle.module.url(
            forResource: "ROUTE_BUS",
            withExtension: "xml"
        ) else {
            throw RealRouteBuilderError.resourceNotFound
        }

        return url
    }
}

enum RealRouteBuilderError: Error {
    case resourceNotFound
}
