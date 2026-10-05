//
//  MTRBusStopCSVReader.swift
//  HK Way
//

import Foundation

struct MTRBusStopRecord: Equatable, Sendable {

    let routeId: String
    let direction: String
    let sequence: Int
    let stopId: String
    let latitude: Double
    let longitude: Double
    let nameTraditional: String
    let nameEnglish: String
    let referenceId: String
}

enum MTRBusStopCSVReaderError: Error {
    case invalidResponse
    case invalidHeader
    case invalidRow(Int)
}

struct MTRBusStopCSVReader {

    private let sourceURL = URL(
        string:
            "https://opendata.mtr.com.hk/data/mtr_bus_stops.csv"
    )!

    func fetch() async throws
        -> [MTRBusStopRecord] {

        let (data, response) =
            try await URLSession.shared.data(
                from: sourceURL
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse,
            (200...299).contains(
                httpResponse.statusCode
            )
        else {
            throw MTRBusStopCSVReaderError
                .invalidResponse
        }

        return try decode(data)
    }

    func decode(
        _ data: Data
    ) throws -> [MTRBusStopRecord] {

        guard var text = String(
            data: data,
            encoding: .utf8
        ) else {
            throw MTRBusStopCSVReaderError
                .invalidHeader
        }

        text.removeUTF8ByteOrderMark()

        let rows = text
            .split(whereSeparator: \.isNewline)
            .map { parseRow(String($0)) }

        guard let header = rows.first else {
            throw MTRBusStopCSVReaderError
                .invalidHeader
        }

        let columns = Dictionary(
            uniqueKeysWithValues:
                header.enumerated().map {
                    ($0.element, $0.offset)
                }
        )

        let requiredColumns = [
            "ROUTE_ID",
            "DIRECTION",
            "STATION_SEQNO",
            "STATION_ID",
            "STATION_LATITUDE",
            "STATION_LONGITUDE",
            "STATION_NAME_CHI",
            "STATION_NAME_ENG",
            "REFERENCE_ID"
        ]

        guard requiredColumns.allSatisfy({
            columns[$0] != nil
        }) else {
            throw MTRBusStopCSVReaderError
                .invalidHeader
        }

        return try rows.dropFirst().enumerated().map {
            offset,
            row in

            let lineNumber = offset + 2

            func value(_ name: String) throws
                -> String {

                guard
                    let index = columns[name],
                    row.indices.contains(index)
                else {
                    throw MTRBusStopCSVReaderError
                        .invalidRow(lineNumber)
                }

                return row[index]
            }

            guard
                let sequence = Int(
                    try value("STATION_SEQNO")
                ),
                let latitude = Double(
                    try value("STATION_LATITUDE")
                ),
                let longitude = Double(
                    try value("STATION_LONGITUDE")
                )
            else {
                throw MTRBusStopCSVReaderError
                    .invalidRow(lineNumber)
            }

            return MTRBusStopRecord(
                routeId: try value("ROUTE_ID"),
                direction: try value("DIRECTION"),
                sequence: sequence,
                stopId: try value("STATION_ID"),
                latitude: latitude,
                longitude: longitude,
                nameTraditional:
                    try value("STATION_NAME_CHI"),
                nameEnglish:
                    try value("STATION_NAME_ENG"),
                referenceId:
                    try value("REFERENCE_ID")
            )
        }
    }

    private func parseRow(
        _ row: String
    ) -> [String] {

        var values: [String] = []
        var value = ""
        var isInsideQuotes = false
        var index = row.startIndex

        while index < row.endIndex {
            let character = row[index]

            if character == "\"" {
                let nextIndex = row.index(
                    after: index
                )

                if isInsideQuotes,
                   nextIndex < row.endIndex,
                   row[nextIndex] == "\"" {
                    value.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",",
                      !isInsideQuotes {
                values.append(value)
                value = ""
            } else {
                value.append(character)
            }

            index = row.index(after: index)
        }

        values.append(value)
        return values
    }
}

private extension String {

    mutating func removeUTF8ByteOrderMark() {

        if first == "\u{FEFF}" {
            removeFirst()
        }
    }
}
