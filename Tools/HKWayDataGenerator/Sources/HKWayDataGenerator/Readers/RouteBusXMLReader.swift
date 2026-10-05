//
//  RouteBusXMLReader.swift
//  HK Way
//
//  Created by Ken on 9/8/2026.
//

import Foundation

struct RouteBusRecord: Sendable {
    let routeID: String
    let companyCode: String
    let number: String
    let serviceMode: String
    let fullFareCents: Int?
    let journeyTimeMinutes: Int?

    let originEnglish: String
    let originTraditional: String
    let originSimplified: String

    let destinationEnglish: String
    let destinationTraditional: String
    let destinationSimplified: String
}

struct RouteBusXMLReader {

    func read(from url: URL) throws -> [RouteBusRecord] {
        let parser = XMLParser(contentsOf: url)
        return try read(using: parser)
    }

    func read(data: Data) throws -> [RouteBusRecord] {
        try read(using: XMLParser(data: data))
    }

    private func read(using parser: XMLParser?) throws -> [RouteBusRecord] {
        let delegate = RouteBusXMLParserDelegate()

        parser?.delegate = delegate

        guard parser?.parse() == true else {
            throw RouteBusXMLReaderError.parseFailed
        }

        return delegate.records
    }
}

enum RouteBusXMLReaderError: Error {
    case parseFailed
}

private final class RouteBusXMLParserDelegate: NSObject, XMLParserDelegate {

    private(set) var records: [RouteBusRecord] = []

    private var currentElement = ""
    private var currentValue = ""

    private var routeID = ""
    private var companyCode = ""
    private var number = ""
    private var serviceMode = ""
    private var fullFareCents: Int?
    private var journeyTimeMinutes: Int?

    private var originEnglish = ""
    private var originTraditional = ""
    private var originSimplified = ""

    private var destinationEnglish = ""
    private var destinationTraditional = ""
    private var destinationSimplified = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentValue = ""

        if elementName == "ROUTE" {
            routeID = ""
            companyCode = ""
            number = ""
            serviceMode = ""
            fullFareCents = nil
            journeyTimeMinutes = nil

            originEnglish = ""
            originTraditional = ""
            originSimplified = ""

            destinationEnglish = ""
            destinationTraditional = ""
            destinationSimplified = ""
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        currentValue += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch elementName {

        case "ROUTE_ID":
            routeID = value

        case "COMPANY_CODE":
            companyCode = value

        case "ROUTE_NAMEE":
            number = value

        case "SERVICE_MODE":
            serviceMode = value

        case "FULL_FARE":
            fullFareCents = Double(value).map {
                Int(($0 * 100).rounded())
            }

        case "JOURNEY_TIME":
            journeyTimeMinutes = Int(value)

        case "LOC_START_NAMEE":
            originEnglish = value

        case "LOC_START_NAMEC":
            originTraditional = value

        case "LOC_START_NAMES":
            originSimplified = value

        case "LOC_END_NAMEE":
            destinationEnglish = value

        case "LOC_END_NAMEC":
            destinationTraditional = value

        case "LOC_END_NAMES":
            destinationSimplified = value

        case "ROUTE":
            records.append(
                RouteBusRecord(
                    routeID: routeID,
                    companyCode: companyCode,
                    number: number,
                    serviceMode: serviceMode,
                    fullFareCents: fullFareCents,
                    journeyTimeMinutes: journeyTimeMinutes,
                    originEnglish: originEnglish,
                    originTraditional: originTraditional,
                    originSimplified: originSimplified,
                    destinationEnglish: destinationEnglish,
                    destinationTraditional: destinationTraditional,
                    destinationSimplified: destinationSimplified
                )
            )

        default:
            break
        }

        currentElement = ""
        currentValue = ""
    }
}
