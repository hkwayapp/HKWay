//
//  DatasetBootstrapper.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation
import SwiftData

@MainActor
struct DatasetBootstrapper {

    func bootstrap(
        modelContext: ModelContext
    ) async throws {
        
        let updateService = DatasetUpdateService()
        let storage = DatasetStorage()
        let reader = DatasetReader()
        let importer = SwiftDataImporter()

        let datasetVersionStore = DatasetVersionStore()
        let importVersionStore = SwiftDataImportVersionStore()

        print(
            "Installed dataset version:",
            datasetVersionStore.installedVersion ?? "none"
        )

        print(
            "Imported SwiftData version:",
            importVersionStore.importedVersion ?? "none"
        )
        
        // -----------------------------------
        // 1. Check remote dataset version
        // -----------------------------------

        let currentDatasetVersion =
            datasetVersionStore.installedVersion ?? "0"

        do {

            let status =
                try await updateService.checkForUpdate(
                    currentVersion: currentDatasetVersion
                )

            switch status {

            case .upToDate:

                print(
                    "Dataset already up to date"
                )

            case .updateAvailable(
                let remoteVersion
            ):

                print(
                    "Downloading dataset:",
                    remoteVersion.version
                )

                let stagingDirectory =
                    try await updateService
                        .downloadAllDatasetFiles()

                try updateService
                    .validateStagedDataset(
                        at: stagingDirectory
                    )

                try updateService
                    .installDataset(
                        from: stagingDirectory,
                        metadata: remoteVersion
                    )

                print(
                    "Dataset installed:",
                    remoteVersion.version
                )
            }

        } catch {

            // A valid installed dataset already exists.
            // A temporary network/server failure should
            // not prevent the app from starting.

            if datasetVersionStore.installedVersion != nil {

                print(
                    "Dataset update check failed; " +
                    "using installed dataset:",
                    error
                )

            } else {

                // First launch with no installed dataset:
                // there is nothing local to fall back to.

                throw error
            }
        }

        // -----------------------------------
        // 2. Determine installed JSON version
        // -----------------------------------

        guard let installedVersion =
            datasetVersionStore.installedVersion
        else {
            throw URLError(.fileDoesNotExist)
        }

        let importedVersion =
            importVersionStore.importedVersion

        print(
            "Installed JSON version:",
            installedVersion
        )

        print(
            "SwiftData imported version:",
            importedVersion ?? "none"
        )

        // -----------------------------------
        // 3. Verify SwiftData actually has data
        // -----------------------------------

        let hasData = try hasImportedData(
            modelContext: modelContext
        )

        print(
            "SwiftData has imported data:",
            hasData
        )

        // Only skip the import when BOTH:
        //
        // 1. the imported version matches
        // 2. SwiftData actually contains data

        if importedVersion == installedVersion &&
            hasData {

            print("SwiftData already up to date")
            print("Dataset bootstrap complete")

            let operatorStopReferenceCount =
                try modelContext.fetchCount(
                    FetchDescriptor<OperatorStopReferenceEntity>()
                )

            print(
                "SwiftData operator stop references:",
                operatorStopReferenceCount
            )
                        
            
            return
        }

        // -----------------------------------
        // 4. Read installed JSON dataset
        // -----------------------------------

        print("Importing dataset into SwiftData")

        let operators = try reader.decodeOperators(
            from: storage.fileURL(
                for: .operators
            )
        )

        let routes = try reader.decodeRoutes(
            from: storage.fileURL(
                for: .routes
            )
        )

        let stops = try reader.decodeStops(
            from: storage.fileURL(
                for: .stops
            )
        )

        let journeys = try reader.decodeJourneys(
            from: storage.fileURL(
                for: .journeys
            )
        )

        let journeyStops =
            try reader.decodeJourneyStops(
                from: storage.fileURL(
                    for: .journeyStops
                )
            )

        let schedules =
            try reader.decodeSchedules(
                from: storage.fileURL(
                    for: .schedules
                )
            )
        
        let operatorStopReferences =
            try reader.decodeOperatorStopReferences(
                from: storage.fileURL(
                    for: .operatorStopReferences
                )
            )
        
        // -----------------------------------
        // 5. Import in dependency order
        // -----------------------------------

        try await importer.importOperators(
            from: operators,
            into: modelContext
        )

        print(
            "Decoded dataset counts:",
            "operators =", operators.count,
            "routes =", routes.count,
            "stops =", stops.count,
            "journeys =", journeys.count,
            "journeyStops =", journeyStops.count,
            "operatorRefs =", operatorStopReferences.count
        )
        
        let operatorCountAfterImport = try modelContext.fetchCount(
            FetchDescriptor<OperatorEntity>()
        )

        print(
            "Operators immediately after import:",
            operatorCountAfterImport
        )
        
        try await importer.importRoutes(
            from: routes,
            into: modelContext
        )

        try await importer.importStops(
            from: stops,
            into: modelContext
        )

        try await importer.importJourneys(
            from: journeys,
            into: modelContext
        )

        try await importer.importJourneyStops(
            from: journeyStops,
            into: modelContext
        )

        try await importer.importSchedules(
            from: schedules,
            into: modelContext
        )

        try await importer.importOperatorStopReferences(
            from: operatorStopReferences,
            into: modelContext
        )
        
        let operatorStopReferenceCount =
            try modelContext.fetchCount(
                FetchDescriptor<OperatorStopReferenceEntity>()
            )

        print(
            "SwiftData operator stop references:",
            operatorStopReferenceCount
        )
        
        // -----------------------------------
        // 6. Verify import really succeeded
        // -----------------------------------

        let importSucceeded = try hasImportedData(
            modelContext: modelContext
        )

        guard importSucceeded else {
            throw DatasetBootstrapError
                .importVerificationFailed
        }

        print("SwiftData import verified")

        // -----------------------------------
        // 7. Mark this version as imported
        // -----------------------------------

        importVersionStore.save(
            version: installedVersion
        )

        print(
            "SwiftData imported version:",
            installedVersion
        )

        print("Dataset bootstrap complete")
    }


    // MARK: - SwiftData Verification

    private func hasImportedData(
        modelContext: ModelContext
    ) throws -> Bool {

        let operatorCount =
            try modelContext.fetchCount(
                FetchDescriptor<OperatorEntity>()
            )

        let routeCount =
            try modelContext.fetchCount(
                FetchDescriptor<RouteEntity>()
            )

        let stopCount =
            try modelContext.fetchCount(
                FetchDescriptor<StopEntity>()
            )

        let journeyCount =
            try modelContext.fetchCount(
                FetchDescriptor<JourneyEntity>()
            )

        print(
            "SwiftData counts:",
            "operators =", operatorCount,
            "routes =", routeCount,
            "stops =", stopCount,
            "journeys =", journeyCount
        )

        return
            operatorCount > 0 &&
            routeCount > 0 &&
            stopCount > 0 &&
            journeyCount > 0
    }
}


// MARK: - Errors

enum DatasetBootstrapError: Error {
    case importVerificationFailed
}
