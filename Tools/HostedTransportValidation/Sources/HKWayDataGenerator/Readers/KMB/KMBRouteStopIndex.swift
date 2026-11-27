import Foundation

struct KMBServiceKey: Hashable, Sendable, CustomStringConvertible {
    let route: String
    let bound: String
    let serviceType: String

    var description: String { "\(route)/\(bound)/\(serviceType)" }
    var apiDirection: String { bound == "I" ? "inbound" : "outbound" }

    init(route: String, bound: String, serviceType: String) throws {
        guard !route.isEmpty, route == route.trimmingCharacters(in: .whitespacesAndNewlines),
              bound == "I" || bound == "O",
              !serviceType.isEmpty, serviceType.utf8.allSatisfy({ (48...57).contains($0) }),
              let number = Int(serviceType), number > 0 else {
            throw KMBRouteStopIntegrityError.invalidService("\(route)/\(bound)/\(serviceType)")
        }
        self.route = route
        self.bound = bound
        self.serviceType = serviceType
    }
}

enum KMBRouteStopIntegrityError: Error, Equatable {
    case invalidService(String)
    case emptyCatalogue
    case duplicateStop(String)
    case unknownStop(KMBServiceKey, String)
    case invalidSequence(KMBServiceKey, String)
    case duplicateSequence(KMBServiceKey, Int)
    case missingGroups([String])
    case unexpectedGroups([String])
    case referenceMismatch(KMBServiceKey)
}

struct KMBRouteStopIndex {
    private let groups: [KMBServiceKey: [KMBRouteStopRecord]]

    init(records: [KMBRouteStopRecord], expected: Set<KMBServiceKey>, knownStops: Set<String>) throws {
        guard !expected.isEmpty, !knownStops.isEmpty else { throw KMBRouteStopIntegrityError.emptyCatalogue }
        var groups: [KMBServiceKey: [KMBRouteStopRecord]] = [:]
        var seenSequences: [KMBServiceKey: Set<Int>] = [:]
        for record in records {
            let key = try KMBServiceKey(route: record.route, bound: record.bound, serviceType: record.serviceType)
            guard knownStops.contains(record.stop) else { throw KMBRouteStopIntegrityError.unknownStop(key, record.stop) }
            guard let sequence = record.sequence, sequence > 0,
                  record.seq.utf8.allSatisfy({ (48...57).contains($0) }) else {
                throw KMBRouteStopIntegrityError.invalidSequence(key, record.seq)
            }
            guard seenSequences[key, default: []].insert(sequence).inserted else {
                throw KMBRouteStopIntegrityError.duplicateSequence(key, sequence)
            }
            groups[key, default: []].append(record)
        }
        let missing = expected.subtracting(groups.keys)
        guard missing.isEmpty else {
            throw KMBRouteStopIntegrityError.missingGroups(missing.map(\.description).sorted())
        }
        let unexpected = Set(groups.keys).subtracting(expected)
        guard unexpected.isEmpty else {
            throw KMBRouteStopIntegrityError.unexpectedGroups(unexpected.map(\.description).sorted())
        }
        self.groups = groups.mapValues { $0.sorted { ($0.sequence ?? 0) < ($1.sequence ?? 0) } }
    }

    func verifyEquivalent(to reference: KMBRouteStopIndex, for key: KMBServiceKey) throws {
        let bulk = try records(for: key)
        let individual = try reference.records(for: key)
        guard bulk.elementsEqual(individual, by: { $0.sequence == $1.sequence && $0.stop == $1.stop }) else {
            throw KMBRouteStopIntegrityError.referenceMismatch(key)
        }
    }

    func records(for key: KMBServiceKey) throws -> [KMBRouteStopRecord] {
        guard let records = groups[key] else {
            throw KMBRouteStopIntegrityError.missingGroups([key.description])
        }
        return records
    }
}
