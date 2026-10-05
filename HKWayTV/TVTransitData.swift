import Foundation
import SwiftUI

enum TVLanguage: String, CaseIterable, Identifiable {
    case english, traditionalChinese, simplifiedChinese
    var id: Self { self }

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en_HK")
        case .traditionalChinese: Locale(identifier: "zh_Hant_HK")
        case .simplifiedChinese: Locale(identifier: "zh_Hans_CN")
        }
    }

    var title: String {
        switch self {
        case .english: "English"
        case .traditionalChinese: "繁體中文"
        case .simplifiedChinese: "简体中文"
        }
    }
}

struct TVMTRStation: Identifiable, Hashable {
    let id: String
    let traditional: String
    let english: String

    var simplified: String {
        traditional.applyingTransform(
            StringTransform("Traditional-Simplified"),
            reverse: false
        ) ?? traditional
    }

    func name(_ language: TVLanguage) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }
}

struct TVMTRPattern: Identifiable, Hashable {
    let id: String
    let lineID: String
    let stations: [TVMTRStation]
}

struct TVMTRLine: Identifiable, Hashable {
    let id: String
    let english: String
    let traditional: String
    let simplified: String
    let rgb: UInt32

    var color: Color {
        Color(
            red: Double((rgb >> 16) & 255) / 255,
            green: Double((rgb >> 8) & 255) / 255,
            blue: Double(rgb & 255) / 255
        )
    }

    func name(_ language: TVLanguage) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }

    static let all: [Self] = [
        .init(id: "TWL", english: "Tsuen Wan Line", traditional: "荃灣綫", simplified: "荃湾线", rgb: 0xE2231A),
        .init(id: "KTL", english: "Kwun Tong Line", traditional: "觀塘綫", simplified: "观塘线", rgb: 0x00AB4E),
        .init(id: "ISL", english: "Island Line", traditional: "港島綫", simplified: "港岛线", rgb: 0x0075C2),
        .init(id: "SIL", english: "South Island Line", traditional: "南港島綫", simplified: "南港岛线", rgb: 0xB5BD00),
        .init(id: "TKL", english: "Tseung Kwan O Line", traditional: "將軍澳綫", simplified: "将军澳线", rgb: 0x6B208B),
        .init(id: "TCL", english: "Tung Chung Line", traditional: "東涌綫", simplified: "东涌线", rgb: 0xF7943E),
        .init(id: "AEL", english: "Airport Express", traditional: "機場快綫", simplified: "机场快线", rgb: 0x00888A),
        .init(id: "DRL", english: "Disneyland Resort Line", traditional: "迪士尼綫", simplified: "迪士尼线", rgb: 0xD49AB8),
        .init(id: "EAL", english: "East Rail Line", traditional: "東鐵綫", simplified: "东铁线", rgb: 0x5EB6E4),
        .init(id: "TML", english: "Tuen Ma Line", traditional: "屯馬綫", simplified: "屯马线", rgb: 0x9A3820)
    ]
}

struct TVLightRailRoute: Identifiable {
    let id: String
    let english: String
    let traditional: String
    let simplified: String
    let rgb: UInt32

    var color: Color {
        Color(
            red: Double((rgb >> 16) & 255) / 255,
            green: Double((rgb >> 8) & 255) / 255,
            blue: Double(rgb & 255) / 255
        )
    }

    func name(_ language: TVLanguage) -> String {
        switch language {
        case .english: english
        case .traditionalChinese: traditional
        case .simplifiedChinese: simplified
        }
    }

    
}

struct TVJourneyLeg: Identifiable {
    let lineID: String
    let stations: [TVMTRStation]
    var id: String { "\(lineID)|\(stations.first?.id ?? "")|\(stations.last?.id ?? "")" }
}

struct TVPlannedJourney {
    let legs: [TVJourneyLeg]
    var changes: Int { max(legs.count - 1, 0) }
    var stops: Int { legs.reduce(0) { $0 + max($1.stations.count - 1, 0) } }
}

struct TVTransitData {
    let patternsByLine: [String: [TVMTRPattern]]
    let stations: [TVMTRStation]

    static func load() throws -> Self {
        guard let url = Bundle.main.url(forResource: "MTRStations", withExtension: "csv") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let csv = try String(contentsOf: url, encoding: .utf8)
        var rowsByLineAndDirection: [String: [(Double, TVMTRStation)]] = [:]
        var uniqueStations: [String: TVMTRStation] = [:]

        for row in csv.components(separatedBy: .newlines).dropFirst() where !row.isEmpty {
            let fields = columns(row)
            guard fields.count == 7, let sequence = Double(fields[6]) else { continue }
            let station = TVMTRStation(
                id: fields[2],
                traditional: fields[4],
                english: fields[5]
            )
            uniqueStations[station.id] = station
            rowsByLineAndDirection["\(fields[0])|\(fields[1])", default: []]
                .append((sequence, station))
        }

        var patterns: [String: [TVMTRPattern]] = [:]
        for (key, rows) in rowsByLineAndDirection {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            patterns[parts[0], default: []].append(
                TVMTRPattern(
                    id: parts[1],
                    lineID: parts[0],
                    stations: rows.sorted { $0.0 < $1.0 }.map(\.1)
                )
            )
        }
        for key in patterns.keys {
            patterns[key]?.sort { $0.id < $1.id }
        }
        return Self(
            patternsByLine: patterns,
            stations: uniqueStations.values.sorted {
                $0.english.localizedStandardCompare($1.english) == .orderedAscending
            }
        )
    }

    func plan(from originID: String, to destinationID: String) -> TVPlannedJourney? {
        guard originID != destinationID else { return nil }
        struct Edge { let station: String; let line: String }
        var graph: [String: [Edge]] = [:]
        for (lineID, patterns) in patternsByLine where lineID != "AEL" {
            for pattern in patterns {
                for pair in zip(pattern.stations, pattern.stations.dropFirst()) {
                    graph[pair.0.id, default: []].append(Edge(station: pair.1.id, line: lineID))
                }
            }
        }

        struct State: Hashable { let station: String; let line: String? }
        struct Cost: Comparable {
            let changes: Int
            let stops: Int
            static func < (lhs: Self, rhs: Self) -> Bool {
                lhs.changes == rhs.changes ? lhs.stops < rhs.stops : lhs.changes < rhs.changes
            }
        }
        let start = State(station: originID, line: nil)
        var costs: [State: Cost] = [start: Cost(changes: 0, stops: 0)]
        var previous: [State: State] = [:]
        var edgeLine: [State: String] = [:]
        var frontier: [State] = [start]
        var end: State?

        while !frontier.isEmpty {
            let currentIndex = frontier.indices.min {
                costs[frontier[$0]]! < costs[frontier[$1]]!
            }!
            let current = frontier.remove(at: currentIndex)
            if current.station == destinationID { end = current; break }
            for edge in graph[current.station] ?? [] {
                let next = State(station: edge.station, line: edge.line)
                let cost = Cost(
                    changes: costs[current]!.changes
                        + ((current.line != nil && current.line != edge.line) ? 1 : 0),
                    stops: costs[current]!.stops + 1
                )
                if costs[next].map({ cost < $0 }) ?? true {
                    costs[next] = cost
                    previous[next] = current
                    edgeLine[next] = edge.line
                    frontier.append(next)
                }
            }
        }
        guard var cursor = end else { return nil }
        var states = [cursor]
        while let prior = previous[cursor] { states.append(prior); cursor = prior }
        states.reverse()
        let stationLookup = Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })
        var legs: [TVJourneyLeg] = []
        var currentLine: String?
        var currentStations: [TVMTRStation] = []
        for index in 1..<states.count {
            let line = edgeLine[states[index]]!
            if line != currentLine {
                if let currentLine, currentStations.count > 1 {
                    legs.append(TVJourneyLeg(lineID: currentLine, stations: currentStations))
                }
                currentLine = line
                currentStations = [stationLookup[states[index - 1].station]!]
            }
            currentStations.append(stationLookup[states[index].station]!)
        }
        if let currentLine, currentStations.count > 1 {
            legs.append(TVJourneyLeg(lineID: currentLine, stations: currentStations))
        }
        return legs.isEmpty ? nil : TVPlannedJourney(legs: legs)
    }

    private static func columns(_ row: String) -> [String] {
        var result: [String] = []
        var value = ""
        var quoted = false
        let characters = Array(row)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    value.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }
            } else if character == ",", !quoted {
                result.append(value)
                value = ""
            } else {
                value.append(character)
            }
            index += 1
        }
        result.append(value)
        return result
    }
}
