//
//  NLBReferenceUpdateCommand.swift
//  HK Way
//

import Foundation

enum NLBReferenceUpdateCommandError: Error {
    case noGeneratedReferences
}

struct NLBReferenceUpdateCommandResult {

    let buildResult:
        NLBOperatorStopReferenceFullBuildResult

    let stageResult:
        NLBReferenceUpdateStageResult

    let outputDirectory: URL
}

struct NLBReferenceUpdateCommand {

    func run(
        in rootDirectory: URL
    ) async throws
        -> NLBReferenceUpdateCommandResult {

        let inputDirectory =
            rootDirectory.appendingPathComponent(
                "Output"
            )

        let outputDirectory =
            rootDirectory.appendingPathComponent(
                "NLBUpdate"
            )

        let routes: [Route] = try decode(
            [Route].self,
            filename: "routes.json",
            directory: inputDirectory
        )

        let journeys: [Journey] = try decode(
            [Journey].self,
            filename: "journeys.json",
            directory: inputDirectory
        )

        let journeyStops: [JourneyStop] = try decode(
            [JourneyStop].self,
            filename: "journey_stops.json",
            directory: inputDirectory
        )

        let stops: [Stop] = try decode(
            [Stop].self,
            filename: "stops.json",
            directory: inputDirectory
        )

        let existingReferences:
            [OperatorStopReference] = try decode(
                [OperatorStopReference].self,
                filename:
                    "operator_stop_references.json",
                directory: inputDirectory
            )

        let buildResult =
            try await NLBOperatorStopReferenceBuilder()
                .buildAll(
                    routes: routes,
                    journeys: journeys,
                    journeyStops: journeyStops,
                    stops: stops
                )

        guard !buildResult.references.isEmpty else {
            throw NLBReferenceUpdateCommandError
                .noGeneratedReferences
        }

        let stageResult =
            try NLBReferenceUpdateStager().stage(
                existingReferences:
                    existingReferences,
                replacementNLBReferences:
                    buildResult.references,
                to: outputDirectory
            )

        return NLBReferenceUpdateCommandResult(
            buildResult: buildResult,
            stageResult: stageResult,
            outputDirectory: outputDirectory
        )
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        filename: String,
        directory: URL
    ) throws -> T {

        let data = try Data(
            contentsOf:
                directory.appendingPathComponent(
                    filename
                )
        )

        return try JSONDecoder().decode(
            type,
            from: data
        )
    }
}
