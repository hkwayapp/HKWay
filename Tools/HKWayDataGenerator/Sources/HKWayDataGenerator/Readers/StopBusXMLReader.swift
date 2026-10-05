//
//  StopBusXMLReader.swift
//  HK Way
//
//  Created by Ken on 8/8/2026.
//

import Foundation

struct StopBusRecord: Sendable {
    let stopID: String
    let stopType: String
    let x: Double
    let y: Double
    let lastUpdateDate: String
}

struct StopBusXMLReader {

    func read(from url: URL) throws -> [StopBusRecord] {
        let parser = XMLParser(contentsOf: url)
        return try read(using: parser)
    }

    func read(data: Data) throws -> [StopBusRecord] {
        try read(using: XMLParser(data: data))
    }

    private func read(using parser: XMLParser?) throws -> [StopBusRecord] {
        let delegate = StopBusXMLParserDelegate()

        parser?.delegate = delegate

        guard let parser else {
            throw StopBusXMLReaderError.unableToCreateParser
        }

        guard parser.parse() else {
            throw parser.parserError ?? StopBusXMLReaderError.parsingFailed
        }

        return delegate.records
    }
}

enum StopBusXMLReaderError: Error {
    case unableToCreateParser
    case parsingFailed
}

private final class StopBusXMLParserDelegate: NSObject, XMLParserDelegate {

    private(set) var records: [StopBusRecord] = []

    private var currentElement = ""
    private var currentValue = ""

    private var stopID = ""
    private var stopType = ""
    private var x = ""
    private var y = ""
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

        if elementName == "STOP" {
            stopID = ""
            stopType = ""
            x = ""
            y = ""
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

        switch elementName {
        case "STOP_ID":
            stopID = value

        case "STOP_TYPE":
            stopType = value

        case "X":
            x = value

        case "Y":
            y = value

        case "LAST_UPDATE_DATE":
            lastUpdateDate = value

        case "STOP":
            if let xValue = Double(x),
               let yValue = Double(y) {

                records.append(
                    StopBusRecord(
                        stopID: stopID,
                        stopType: stopType,
                        x: xValue,
                        y: yValue,
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
