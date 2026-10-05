import Foundation

@main
struct HKWayDataGeneratorApp {

    static func main() async {

        print("""
        ===========================
        HK Way Data Generator
        ===========================
        """)

        do {
            let rootDirectory = URL(
                fileURLWithPath:
                    FileManager.default
                        .currentDirectoryPath
            )

            if CommandLine.arguments.contains(
                "--stage-gmb-update"
            ) {
                let result = try await GMBUpdateCommand()
                    .run(in: rootDirectory)

                print("")
                print("*** GMB update staged ***")
                print("Routes:", result.routeCount)
                print("Journeys:", result.journeyCount)
                print("Journey stops:", result.journeyStopCount)
                print("Stops:", result.stopCount)
                print("ETA references:", result.referenceCount)
                print("Output:", result.outputDirectory.path)
                return
            }

            if CommandLine.arguments.contains(
                "--stage-journey-shapes"
            ) {
                let result = try await
                    JourneyShapeUpdateCommand()
                        .run(in: rootDirectory)

                print("")
                print("*** Journey shapes staged ***")
                print(
                    "Shapes:",
                    result.stageResult.shapeCount
                )
                print(
                    "Coordinates:",
                    result.stageResult.coordinateCount
                )
                print(
                    "Encoded bytes:",
                    result.stageResult.encodedByteCount
                )
                print(
                    "Version:",
                    result.stageResult.version.version
                )
                print(
                    "Output:",
                    result.outputDirectory.path
                )
                return
            }

            if CommandLine.arguments.contains(
                "--stage-nlb-update"
            ) {
                let result = try await
                    NLBReferenceUpdateCommand()
                        .run(in: rootDirectory)

                print("")
                print("*** NLB update staged ***")
                print(
                    "NLB references:",
                    result.stageResult
                        .nlbReferenceCount
                )
                print(
                    "Matched journeys:",
                    result.buildResult
                        .matchedJourneys
                )
                print(
                    "Ambiguous journeys:",
                    result.buildResult
                        .ambiguousJourneys.count
                )
                print(
                    "Rejected journeys:",
                    result.buildResult
                        .rejectedJourneys.count
                )
                print(
                    "Total references:",
                    result.stageResult
                        .referenceCount
                )
                print(
                    "Version:",
                    result.stageResult
                        .version.version
                )
                print(
                    "Output:",
                    result.outputDirectory.path
                )
                return
            }

            if CommandLine.arguments.contains(
                "--stage-mtr-bus-update"
            ) {
                let result = try await
                    MTRBusReferenceUpdateCommand()
                        .run(in: rootDirectory)

                print("")
                print("*** MTR Bus update staged ***")

                let groupedResults = Dictionary(
                    grouping: result.buildResults,
                    by: \.routeNumber
                )

                for routeNumber in
                    groupedResults.keys.sorted() {
                    let routeResults = groupedResults[
                        routeNumber,
                        default: []
                    ]

                    print(
                        routeNumber,
                        "| journeys:",
                        routeResults.count,
                        "| references:",
                        routeResults
                            .flatMap(\.references)
                            .count
                    )
                }

                print(
                    "MTR Bus references:",
                    result.stageResult
                        .mtrBusReferenceCount
                )
                print(
                    "Total references:",
                    result.stageResult.referenceCount
                )
                print(
                    "Version:",
                    result.stageResult.version.version
                )
                print(
                    "Output:",
                    result.outputDirectory.path
                )
                return
            }

            if CommandLine.arguments.contains(
                "--export-journey-stops"
            ) {
                let journeyStops = try RealJourneyStopBuilder().build()
                let datasetDirectory = rootDirectory
                    .appendingPathComponent("Dataset")
                let outputURL = datasetDirectory
                    .appendingPathComponent("journey_stops.json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = [
                    .prettyPrinted,
                    .sortedKeys
                ]

                try FileManager.default.createDirectory(
                    at: datasetDirectory,
                    withIntermediateDirectories: true
                )
                try encoder.encode(journeyStops).write(to: outputURL)

                print("Journey stops exported:", journeyStops.count)
                print("Output:", outputURL.path)
                return
            }

            if CommandLine.arguments.contains(
                "--stage-stop-geography"
            ) {
                let result = try await
                    StopGeographyUpdateCommand()
                        .run(in: rootDirectory)

                print("")
                print("*** Stop geography staged ***")
                print("Stops:", result.stopCount)
                print("Classified:", result.classifiedStopCount)
                print("Unclassified:", result.unclassifiedStopCount)
                print("Version:", result.version.version)
                print("Output:", result.outputURL.path)
                return
            }

            let masterData =
                try await RealDataBuilder().build()

            let outputDirectory =
                rootDirectory.appendingPathComponent(
                    "Output"
                )

            try MasterDataExporter().export(
                masterData,
                to: outputDirectory
            )

            print("Export completed.")
            print(
                "Output:",
                outputDirectory.path
            )

            print(
                "Operators:",
                masterData.operators.count
            )

            print(
                "Routes:",
                masterData.routes.count
            )

            print(
                "Journeys:",
                masterData.journeys.count
            )

            print(
                "JourneyStops:",
                masterData.journeyStops.count
            )

            print(
                "Stops:",
                masterData.stops.count
            )

            print(
                "Schedules:",
                masterData.schedules.count
            )

            print(
                "Operator stop references:",
                masterData
                    .operatorStopReferences
                    .count
            )

        } catch {
            print(
                "ERROR:",
                error
            )
        }
    }
}
