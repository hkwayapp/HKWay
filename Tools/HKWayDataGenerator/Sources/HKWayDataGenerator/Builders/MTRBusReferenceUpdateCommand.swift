//
//  MTRBusReferenceUpdateCommand.swift
//  HK Way
//

import Foundation

enum MTRBusReferenceUpdateCommandError: Error {
    case incompleteRoutes(Int)
    case incompleteJourneys(Int)
}

struct MTRBusReferenceUpdateCommandResult {
    let buildResults:
        [MTRBusOperatorStopReferenceBuildResult]
    let stageResult:
        MTRBusReferenceUpdateStageResult
    let outputDirectory: URL
}

struct MTRBusReferenceUpdateCommand {

    func run(
        in rootDirectory: URL
    ) async throws
        -> MTRBusReferenceUpdateCommandResult {

        let inputDirectory = rootDirectory
            .appendingPathComponent("Dataset")
        let outputDirectory = rootDirectory
            .appendingPathComponent("MTRBusUpdate")

        let routes: [Route] = try decode(
            "routes.json",
            from: inputDirectory
        )
        let journeys: [Journey] = try decode(
            "journeys.json",
            from: inputDirectory
        )
        let journeyStops: [JourneyStop] = try decode(
            "journey_stops.json",
            from: inputDirectory
        )
        let stops: [Stop] = try decode(
            "stops.json",
            from: inputDirectory
        )
        let existingReferences:
            [OperatorStopReference] = try decode(
                "operator_stop_references.json",
                from: inputDirectory
            )
        let currentVersion: DataVersion = try decode(
            "dataset_info.json",
            from: inputDirectory
        )

        let buildResults = try await
            MTRBusOperatorStopReferenceBuilder()
                .buildAll(
                    routes: routes,
                    journeys: journeys,
                    journeyStops: journeyStops,
                    stops: stops
                )

        let routeNumbers = Set(
            buildResults.map(\.routeNumber)
        )

        guard routeNumbers.count == 22 else {
            throw MTRBusReferenceUpdateCommandError
                .incompleteRoutes(routeNumbers.count)
        }

        guard buildResults.count == 45 else {
            throw MTRBusReferenceUpdateCommandError
                .incompleteJourneys(buildResults.count)
        }

        let replacementReferences = buildResults
            .flatMap(\.references)

        let stageResult = try
            MTRBusReferenceUpdateStager().stage(
                existingReferences:
                    existingReferences,
                replacementReferences:
                    replacementReferences,
                currentVersion: currentVersion,
                to: outputDirectory
            )

        return MTRBusReferenceUpdateCommandResult(
            buildResults: buildResults,
            stageResult: stageResult,
            outputDirectory: outputDirectory
        )
    }

    private func decode<T: Decodable>(
        _ filename: String,
        from directory: URL
    ) throws -> T {

        try JSONDecoder().decode(
            T.self,
            from: Data(
                contentsOf:
                    directory.appendingPathComponent(
                        filename
                    )
            )
        )
    }
}
