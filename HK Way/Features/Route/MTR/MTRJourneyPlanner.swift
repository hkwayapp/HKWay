import Foundation

struct MTRJourneyLeg: Sendable {
    let lineID: String
    let pattern: MTRStationPattern
    let stations: [MTRStation]
    var stopCount: Int { max(0, stations.count - 1) }
}

struct MTRPlannedJourney: Sendable {
    let legs: [MTRJourneyLeg]
    var changes: Int { max(0, legs.count - 1) }
    var stops: Int { legs.reduce(0) { $0 + $1.stopCount } }
}

// Route-pattern states are intentional: changing trains on the same line
// (e.g. Po Lam -> LOHAS Park) must still count as a change.
struct MTRJourneyPlanner: Sendable {
    let patternsByLine: [String: [MTRStationPattern]]
    let stations: [MTRStation]
    private let nodes: [Node]
    private let nodesAtStation: [String: [Int]]

    private struct Node: Sendable {
        let lineID: String
        let pattern: MTRStationPattern
        let position: Int
        let next: Int?
        var station: MTRStation { pattern.stations[position] }
    }
    private struct Cost: Comparable {
        let changes: Int
        let stops: Int
        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.changes != rhs.changes ? lhs.changes < rhs.changes : lhs.stops < rhs.stops
        }
    }

    init(csv: String, lineIDs: [String]) throws {
        var lines: [String: [MTRStationPattern]] = [:]
        var nodes: [Node] = []
        var atStation: [String: [Int]] = [:]
        var stations: [String: MTRStation] = [:]
        // Airport Express requires separate access and fare rules.
        for lineID in Set(lineIDs).subtracting(["AEL"]).sorted() {
            let patterns = try MTRStations.parse(csv, line: lineID)
            lines[lineID] = patterns
            for pattern in patterns {
                for position in pattern.stations.indices {
                    let index = nodes.count
                    let station = pattern.stations[position]
                    nodes.append(Node(lineID: lineID, pattern: pattern, position: position,
                                      next: position + 1 < pattern.stations.count ? index + 1 : nil))
                    atStation[station.id, default: []].append(index)
                    stations[station.id] = station
                }
            }
        }
        self.patternsByLine = lines
        self.nodes = nodes
        self.nodesAtStation = atStation
        self.stations = stations.values.sorted { $0.english.localizedStandardCompare($1.english) == .orderedAscending }
    }

    func plan(from: String, to: String) -> MTRPlannedJourney? {
        guard from != to, let starts = nodesAtStation[from], nodesAtStation[to] != nil else { return nil }
        var costs: [Int: Cost] = [:]
        var previous: [Int: Int] = [:]
        var frontier: [(node: Int, cost: Cost)] = []
        for start in starts {
            let cost = Cost(changes: 0, stops: 0)
            costs[start] = cost
            frontier.append((start, cost))
        }
        var end: Int?
        while !frontier.isEmpty {
            guard !Task.isCancelled else { return nil }
            let best = frontier.indices.min {
                frontier[$0].cost == frontier[$1].cost
                    ? frontier[$0].node < frontier[$1].node
                    : frontier[$0].cost < frontier[$1].cost
            }!
            let current = frontier.remove(at: best)
            guard costs[current.node] == current.cost else { continue }
            let node = nodes[current.node]
            if node.station.id == to { end = current.node; break }
            var neighbors: [(Int, Cost)] = []
            if let next = node.next {
                neighbors.append((next, Cost(changes: current.cost.changes, stops: current.cost.stops + 1)))
            }
            // Only exact shared station codes are verified interchanges.
            for next in nodesAtStation[node.station.id] ?? [] where next != current.node {
                neighbors.append((next, Cost(changes: current.cost.changes + 1, stops: current.cost.stops)))
            }
            for (next, cost) in neighbors where costs[next].map({ cost < $0 }) ?? true {
                costs[next] = cost
                previous[next] = current.node
                frontier.append((next, cost))
            }
        }
        guard let end else { return nil }
        var path = [end]
        while let parent = previous[path.last!] { path.append(parent) }
        path.reverse()
        var legs: [MTRJourneyLeg] = []
        var ride: [MTRStation] = []
        var boarding: Node?
        func finishLeg() {
            if let boarding, ride.count > 1 {
                legs.append(MTRJourneyLeg(lineID: boarding.lineID, pattern: boarding.pattern, stations: ride))
            }
            ride = []
            boarding = nil
        }
        for (a, b) in zip(path, path.dropFirst()) {
            if nodes[a].next == b {
                if boarding == nil { boarding = nodes[a]; ride = [nodes[a].station] }
                ride.append(nodes[b].station)
            } else { finishLeg() }
        }
        finishLeg()
        return legs.isEmpty ? nil : MTRPlannedJourney(legs: legs)
    }
}
