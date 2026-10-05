import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GMBUpdateCommandResult {
    let routeCount: Int
    let journeyCount: Int
    let journeyStopCount: Int
    let stopCount: Int
    let referenceCount: Int
    let outputDirectory: URL
}

struct GMBUpdateCommand {
    private let baseURL = URL(
        string: "https://static.data.gov.hk/td/routes-fares-xml/"
    )!
    private let coordinateConverter = HKGridConverter()

    func run(in rootDirectory: URL) async throws -> GMBUpdateCommandResult {
        let inputDirectory = rootDirectory.appendingPathComponent("Dataset")
        let outputDirectory = rootDirectory.appendingPathComponent("GMBUpdate")

        async let routeData = fetch(filename: "ROUTE_GMB.xml")
        async let routeStopData = fetch(filename: "RSTOP_GMB.xml")
        async let stopData = fetch(filename: "STOP_GMB.xml")

        let routeRecords = try RouteBusXMLReader().read(data: await routeData)
        let routeStopRecords = try RStopBusXMLReader().read(data: await routeStopData)
        let stopRecords = try StopBusXMLReader().read(data: await stopData)
        let generated = build(
            routes: routeRecords.filter { $0.companyCode == "GMB" },
            routeStops: routeStopRecords,
            stops: stopRecords
        )

        let operators: [Operator] = try decode("operators.json", from: inputDirectory)
        let existingRoutes: [Route] = try decode("routes.json", from: inputDirectory)
        let existingJourneys: [Journey] = try decode("journeys.json", from: inputDirectory)
        let existingJourneyStops: [JourneyStop] = try decode("journey_stops.json", from: inputDirectory)
        let existingStops: [Stop] = try decode("stops.json", from: inputDirectory)
        let schedules: [Schedule] = try decode("schedules.json", from: inputDirectory)
        let existingReferences: [OperatorStopReference] = try decode(
            "operator_stop_references.json",
            from: inputDirectory
        )

        let oldRouteIds = Set(
            existingRoutes.filter { $0.operatorIds.contains("GMB") }.map(\.id)
        )
        let oldJourneyIds = Set(
            existingJourneys.filter { oldRouteIds.contains($0.routeId) }.map(\.id)
        )
        let oldStopIds = Set(
            existingJourneyStops.filter { oldJourneyIds.contains($0.journeyId) }.map(\.stopId)
        )

        let masterData = MasterData(
            operators: operators,
            routes: existingRoutes.filter { !$0.operatorIds.contains("GMB") }
                + generated.routes,
            journeys: existingJourneys.filter { !oldRouteIds.contains($0.routeId) }
                + generated.journeys,
            journeyStops: existingJourneyStops.filter {
                !oldJourneyIds.contains($0.journeyId)
            } + generated.journeyStops,
            stops: existingStops.filter { !oldStopIds.contains($0.id) }
                + generated.stops,
            schedules: schedules,
            operatorStopReferences: existingReferences.filter {
                $0.operatorId != "GMB"
            } + generated.references
        )

        try MasterDataExporter().export(masterData, to: outputDirectory)

        return GMBUpdateCommandResult(
            routeCount: generated.routes.count,
            journeyCount: generated.journeys.count,
            journeyStopCount: generated.journeyStops.count,
            stopCount: generated.stops.count,
            referenceCount: generated.references.count,
            outputDirectory: outputDirectory
        )
    }

    private func fetch(filename: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(filename)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw GMBUpdateError.invalidResponse(filename)
        }
        return data
    }

    private func build(
        routes routeRecords: [RouteBusRecord],
        routeStops routeStopRecords: [RStopBusRecord],
        stops stopRecords: [StopBusRecord]
    ) -> GeneratedGMBData {
        let routeStopsByRoute = Dictionary(grouping: routeStopRecords, by: \.routeID)
        let stopCoordinates = Dictionary(
            stopRecords.map { ($0.stopID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var namesByStopId: [String: RStopBusRecord] = [:]
        var journeys: [Journey] = []
        var journeyStops: [JourneyStop] = []
        var references: [OperatorStopReference] = []

        let routes = routeRecords.compactMap { record -> Route? in
            let records = routeStopsByRoute[record.routeID] ?? []
            let sequences = Dictionary(grouping: records, by: \.routeSequence)
            guard !sequences.isEmpty else { return nil }

            for (routeSequence, unsortedStops) in sequences {
                let stops = unsortedStops.sorted { $0.stopSequence < $1.stopSequence }
                guard let first = stops.first, let last = stops.last else { continue }
                let routeId = "gmb-\(record.routeID)"
                let journeyId = "\(routeId)-\(routeSequence)"

                journeys.append(
                    Journey(
                        id: journeyId,
                        routeId: routeId,
                        originStopId: "gmb-\(first.stopID)",
                        destinationStopId: "gmb-\(last.stopID)",
                        direction: String(routeSequence),
                        serviceType: "GMB",
                        adultFullFareCents: record.fullFareCents,
                        scheduledDurationMinutes: record.journeyTimeMinutes
                    )
                )

                for stop in stops {
                    guard let coordinateRecord = stopCoordinates[stop.stopID] else {
                        continue
                    }
                    namesByStopId[stop.stopID] = namesByStopId[stop.stopID] ?? stop
                    let coordinate = coordinateConverter.convert(
                        easting: coordinateRecord.x,
                        northing: coordinateRecord.y
                    )
                    let canonicalStopId = "gmb-\(stop.stopID)"

                    journeyStops.append(
                        JourneyStop(
                            journeyId: journeyId,
                            stopId: canonicalStopId,
                            sequence: stop.stopSequence,
                            stopPickDrop: stop.stopPickDrop
                        )
                    )
                    references.append(
                        OperatorStopReference(
                            operatorId: "GMB",
                            journeyId: journeyId,
                            stopId: canonicalStopId,
                            sequence: stop.stopSequence,
                            operatorStopId: stop.stopID,
                            operatorLatitude: coordinate.latitude,
                            operatorLongitude: coordinate.longitude,
                            operatorServiceType: "\(record.routeID)|\(stop.stopSequence)",
                            operatorDirection: String(routeSequence)
                        )
                    )
                }
            }

            return Route(
                id: "gmb-\(record.routeID)",
                number: record.number,
                operatorIds: ["GMB"],
                originEnglish: record.originEnglish,
                originTraditional: record.originTraditional,
                originSimplified: record.originSimplified,
                destinationEnglish: record.destinationEnglish,
                destinationTraditional: record.destinationTraditional,
                destinationSimplified: record.destinationSimplified
            )
        }

        let stops = namesByStopId.compactMap { stopId, names -> Stop? in
            guard let record = stopCoordinates[stopId] else { return nil }
            let coordinate = coordinateConverter.convert(
                easting: record.x,
                northing: record.y
            )
            return Stop(
                id: "gmb-\(stopId)",
                nameEnglish: names.nameEnglish,
                nameTraditional: names.nameTraditional,
                nameSimplified: names.nameSimplified,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }

        return GeneratedGMBData(
            routes: routes.sorted { $0.id < $1.id },
            journeys: journeys.sorted { $0.id < $1.id },
            journeyStops: journeyStops.sorted(by: journeyStopOrder),
            stops: stops.sorted { $0.id < $1.id },
            references: references.sorted(by: referenceOrder)
        )
    }

    private func journeyStopOrder(_ lhs: JourneyStop, _ rhs: JourneyStop) -> Bool {
        lhs.journeyId == rhs.journeyId
            ? lhs.sequence < rhs.sequence
            : lhs.journeyId < rhs.journeyId
    }

    private func referenceOrder(
        _ lhs: OperatorStopReference,
        _ rhs: OperatorStopReference
    ) -> Bool {
        lhs.journeyId == rhs.journeyId
            ? lhs.sequence < rhs.sequence
            : lhs.journeyId < rhs.journeyId
    }

    private func decode<T: Decodable>(
        _ filename: String,
        from directory: URL
    ) throws -> T {
        let data = try Data(contentsOf: directory.appendingPathComponent(filename))
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct GeneratedGMBData {
    let routes: [Route]
    let journeys: [Journey]
    let journeyStops: [JourneyStop]
    let stops: [Stop]
    let references: [OperatorStopReference]
}

enum GMBUpdateError: Error {
    case invalidResponse(String)
}
