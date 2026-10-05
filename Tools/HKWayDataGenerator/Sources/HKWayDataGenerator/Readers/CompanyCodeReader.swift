//
//  CompanyCodeReader.swift
//  HK Way
//
//  Created by Ken on 8/8/2026.
//

import Foundation

final class CompanyCodeReader: NSObject, XMLParserDelegate {
    
    private var operators: [Operator] = []

    private var currentElement = ""
    private var currentDepth = 0
    private var companyRecordDepth: Int?

    private var currentCode = ""
    private var currentTraditional = ""
    private var currentSimplified = ""
    private var currentEnglish = ""
    private var currentDescription = ""

    func read(from url: URL) throws -> [Operator] {
        operators.removeAll()
        currentDepth = 0
        companyRecordDepth = nil

        guard let parser = XMLParser(contentsOf: url) else {
            throw NSError(
                domain: "CompanyCodeReader",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to create XML parser"
                ]
            )
        }

        parser.delegate = self

        guard parser.parse() else {
            throw parser.parserError ?? NSError(
                domain: "CompanyCodeReader",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to parse COMPANY_CODE.xml"
                ]
            )
        }

        return operators
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentDepth += 1
        currentElement = elementName

        if elementName == "COMPANY_CODE",
           companyRecordDepth == nil {

            companyRecordDepth = currentDepth

            currentCode = ""
            currentTraditional = ""
            currentSimplified = ""
            currentEnglish = ""
            currentDescription = ""
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        switch currentElement {
        case "COMPANY_CODE":
            currentCode += string
        case "COMPANY_NAMEC":
            currentTraditional += string
        case "COMPANY_NAMES":
            currentSimplified += string
        case "COMPANY_NAMEE":
            currentEnglish += string
        case "DESCRIPTION":
            currentDescription += string
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "COMPANY_CODE",
           currentDepth == companyRecordDepth {

            let code = currentCode.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !code.isEmpty {
                operators.append(
                    Operator(
                        id: code,
                        nameEnglish: currentDescription.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        nameTraditional: currentTraditional.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        nameSimplified: currentSimplified.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        transportTypes: []
                    )
                )
            }

            companyRecordDepth = nil
        }

        currentDepth -= 1
        currentElement = ""
    }
}
