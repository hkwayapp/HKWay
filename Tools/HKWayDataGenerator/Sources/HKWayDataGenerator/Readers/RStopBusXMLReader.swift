//
//  RStopBusXMLReader.swift
//  HK Way
//
//  Created by Ken on 8/8/2026.
//

import Foundation

struct RStopBusRecord: Sendable {
    let routeID: String
    let routeSequence: Int
    let stopSequence: Int
    let stopID: String
    let stopPickDrop: String
    let nameTraditional: String
    let nameSimplified: String
    let nameEnglish: String
    let lastUpdateDate: String
}

struct RStopBusXMLReader {

    func read(from url: URL) throws -> [RStopBusRecord] {
        let parser = XMLParser(contentsOf: url)
        return try read(using: parser)
    }

    func read(data: Data) throws -> [RStopBusRecord] {
        try read(using: XMLParser(data: data))
    }

    private func read(using parser: XMLParser?) throws -> [RStopBusRecord] {
        let delegate = RStopBusXMLParserDelegate()

        parser?.delegate = delegate

        guard let parser else {
            throw RStopBusXMLReaderError.unableToCreateParser
        }

        guard parser.parse() else {
            throw parser.parserError ?? RStopBusXMLReaderError.parsingFailed
        }

        return delegate.records
    }
}

enum RStopBusXMLReaderError: Error {
    case unableToCreateParser
    case parsingFailed
}

private final class RStopBusXMLParserDelegate: NSObject, XMLParserDelegate {

    private(set) var records: [RStopBusRecord] = []

    private var currentElement = ""
    private var currentValue = ""

    private var routeID = ""
    private var routeSequence = ""
    private var stopSequence = ""
    private var stopID = ""
    private var stopPickDrop = ""
    private var nameTraditional = ""
    private var nameSimplified = ""
    private var nameEnglish = ""
    private var lastUpdateDate = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentValue = ""

        if elementName == "RSTOP" {
            routeID = ""
            routeSequence = ""
            stopSequence = ""
            stopID = ""
            stopPickDrop = ""
            nameTraditional = ""
            nameSimplified = ""
            nameEnglish = ""
            lastUpdateDate = ""
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

        //print("ROUTE field:", elementName, "=", value)
        
        switch elementName {
        case "ROUTE_ID":
            routeID = value

        case "ROUTE_SEQ":
            routeSequence = value

        case "STOP_SEQ":
            stopSequence = value

        case "STOP_ID":
            stopID = value

        case "STOP_PICK_DROP":
            stopPickDrop = value

        case "STOP_NAMEC":
            nameTraditional = value

        case "STOP_NAMES":
            nameSimplified = value

        case "STOP_NAMEE":
            nameEnglish = value

        case "LAST_UPDATE_DATE":
            lastUpdateDate = value

        case "RSTOP":
            if let routeSequenceValue = Int(routeSequence),
               let stopSequenceValue = Int(stopSequence) {

                records.append(
                    RStopBusRecord(
                        routeID: routeID,
                        routeSequence: routeSequenceValue,
                        stopSequence: stopSequenceValue,
                        stopID: stopID,
                        stopPickDrop: stopPickDrop,
                        nameTraditional: nameTraditional,
                        nameSimplified: nameSimplified,
                        nameEnglish: nameEnglish,
                        lastUpdateDate: lastUpdateDate
                    )
                )
            }

        default:
            break
        }

        currentElement = ""
        currentValue = ""
    }
}
