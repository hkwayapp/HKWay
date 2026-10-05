//
//  DatasetUpdateService.swift
//  HK Way
//
//  Created by Ken on 10/8/2026.
//

import Foundation

enum DatasetUpdateStatus {
    case upToDate
    case updateAvailable(DataVersion)
}

enum DatasetFile: String, CaseIterable {
    case operators = "operators.json"
    case routes = "routes.json"
    case journeys = "journeys.json"
    case journeyStops = "journey_stops.json"
    case stops = "stops.json"
    case schedules = "schedules.json"
    case operatorStopReferences = "operator_stop_references.json"
    case journeyShapes = "journey_shapes.json"
}

struct DatasetUpdateService {

    private let metadataURL = URL(
        string: "https://raw.githubusercontent.com/hkwayapp/HKWay/main/Dataset/dataset_info.json"
    )!
    
    private let datasetBaseURL = URL(
        string: "https://raw.githubusercontent.com/hkwayapp/HKWay/main/Dataset/"
    )!
    
    private let operatorsURL = URL(
        string: "https://raw.githubusercontent.com/hkwayapp/HKWay/main/Dataset/operators.json"
    )!
    

    func fetchRemoteVersion() async throws -> DataVersion {

        var request = URLRequest(
            url: metadataURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )

        request.setValue(
            "no-cache",
            forHTTPHeaderField: "Cache-Control"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let version = try JSONDecoder().decode(
            DataVersion.self,
            from: data
        )

        print("Remote dataset version:", version.version)

        return version
    }
    
    func checkForUpdate(
        currentVersion: String
    ) async throws -> DatasetUpdateStatus {

        let remoteVersion = try await fetchRemoteVersion()

        if remoteVersion.version == currentVersion {
            return .upToDate
        }

        if isNewer(
            remote: remoteVersion.version,
            than: currentVersion
        ) {
            return .updateAvailable(remoteVersion)
        }

        return .upToDate
    }
    
    private func isNewer(
        remote: String,
        than current: String
    ) -> Bool {

        let remoteParts = remote
            .split(separator: ".")
            .compactMap { Int($0) }

        let currentParts = current
            .split(separator: ".")
            .compactMap { Int($0) }

        for index in 0..<min(remoteParts.count, currentParts.count) {
            if remoteParts[index] > currentParts[index] {
                return true
            }

            if remoteParts[index] < currentParts[index] {
                return false
            }
        }

        return remoteParts.count > currentParts.count
    }
    
    func download(
        _ file: DatasetFile
    ) async throws -> URL {

        let remoteURL = datasetBaseURL
            .appendingPathComponent(file.rawValue)

        let (data, response) = try await URLSession.shared.data(
            from: remoteURL
        )

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(file.rawValue)

        try data.write(to: temporaryURL)

        return temporaryURL
    }
    

    func downloadAllDatasetFiles() async throws -> URL {
        let stagingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransitGoDatasetStaging")

        if FileManager.default.fileExists(atPath: stagingDirectory.path) {
            try FileManager.default.removeItem(at: stagingDirectory)
        }

        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )

        for file in DatasetFile.allCases {

            print(
                "Downloading dataset file:",
                file.rawValue
            )

            let remoteURL = datasetBaseURL
                .appendingPathComponent(file.rawValue)

            var request = URLRequest(
                url: remoteURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 60
            )

            request.setValue(
                "no-cache",
                forHTTPHeaderField: "Cache-Control"
            )

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let localURL = stagingDirectory
                .appendingPathComponent(file.rawValue)

            try data.write(to: localURL)

            print(
                "Saved staged file:",
                localURL.path
            )
        }

        return stagingDirectory
    }
    
    func validateStagedDataset(
        at directory: URL
    ) throws {

        for file in DatasetFile.allCases {
        
            let fileURL = directory
                .appendingPathComponent(file.rawValue)

            guard FileManager.default.fileExists(
                atPath: fileURL.path
            ) else {
                throw URLError(.fileDoesNotExist)
            }
        }

        let reader = DatasetReader()
        
        let operatorsURL = directory.appendingPathComponent(DatasetFile.operators.rawValue)
        let routesURL = directory.appendingPathComponent(DatasetFile.routes.rawValue)
        let stopsURL = directory.appendingPathComponent(DatasetFile.stops.rawValue)
        let journeysURL = directory.appendingPathComponent(DatasetFile.journeys.rawValue)
        let journeyStopsURL = directory.appendingPathComponent(DatasetFile.journeyStops.rawValue)
        let schedulesURL = directory.appendingPathComponent(DatasetFile.schedules.rawValue)
        
        let routes = try reader.decodeRoutes(from: routesURL )
        let operators = try reader.decodeOperators(from: operatorsURL)
        let stops = try reader.decodeStops(from: stopsURL)
        let journeys = try reader.decodeJourneys(from: journeysURL)
        let journeyStops = try reader.decodeJourneyStops(from: journeyStopsURL)
        let schedules = try reader.decodeSchedules(from: schedulesURL)
        
        let routeIds = Set(routes.map(\.id))
        let stopIds = Set(stops.map(\.id))
        let journeyIds = Set(journeys.map(\.id))
        let operatorIds = Set(operators.map(\.id))
        let journeyStopIds = Set(
            journeyStops.map {
                "\($0.journeyId)|\($0.sequence)"
            }
        )
        let scheduleIds = Set(schedules.map(\.id))
        
        guard !routes.isEmpty else { throw URLError(.cannotDecodeContentData) }
        guard !operators.isEmpty else { throw URLError(.cannotDecodeContentData) }
        guard !stops.isEmpty else { throw URLError(.cannotDecodeContentData) }
        guard !journeys.isEmpty else { throw URLError(.cannotDecodeContentData) }
        guard !journeyStops.isEmpty else { throw URLError(.cannotDecodeContentData) }

        guard routeIds.count == routes.count else {
            throw URLError(.cannotDecodeContentData)
        }

        guard journeyIds.count == journeys.count else {
            throw URLError(.cannotDecodeContentData)
        }

        guard stopIds.count == stops.count else {
            throw URLError(.cannotDecodeContentData)
        }

        guard operatorIds.count == operators.count else {
            throw URLError(.cannotDecodeContentData)
        }

        guard journeyStopIds.count == journeyStops.count else {
            throw URLError(.cannotDecodeContentData)
        }

        guard scheduleIds.count == schedules.count else {
            throw URLError(.cannotDecodeContentData)
        }
        
        for journey in journeys {
            guard routeIds.contains(journey.routeId) else {
                throw URLError(.cannotDecodeContentData)
            }

            guard stopIds.contains(journey.originStopId) else {
                throw URLError(.cannotDecodeContentData)
            }

            guard stopIds.contains(journey.destinationStopId) else {
                throw URLError(.cannotDecodeContentData)
            }
        }
        
        for journeyStop in journeyStops {
            guard journeyIds.contains(journeyStop.journeyId) else {
                throw URLError(.cannotDecodeContentData)
            }

            guard stopIds.contains(journeyStop.stopId) else {
                throw URLError(.cannotDecodeContentData)
            }
        }

        for schedule in schedules {
            guard journeyIds.contains(schedule.journeyId) else {
                throw URLError(.cannotDecodeContentData)
            }
        }
   
        for route in routes {
            for operatorId in route.operatorIds {
                guard operatorIds.contains(operatorId) else {
                    throw URLError(.cannotDecodeContentData)
                }
            }
        }
        
        print("Operators:", operators.count)
        print("Routes:", routes.count)
        print("Stops:", stops.count)
        print("Journeys:", journeys.count)
        print("Journey stops:", journeyStops.count)
        print("Schedules:", schedules.count)
        
        print("Relationship validation passed")
        print("Operator relationship validation passed")
    }

    func installDataset(
        from stagingDirectory: URL,
        metadata: DataVersion
    ) throws {

        let fileManager = FileManager.default

        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let datasetDirectory = applicationSupport
            .appendingPathComponent("TransitGoDataset")

        let newDatasetDirectory = applicationSupport
            .appendingPathComponent("TransitGoDataset-New")

        if fileManager.fileExists(
            atPath: newDatasetDirectory.path
        ) {
            try fileManager.removeItem(
                at: newDatasetDirectory
            )
        }

        try fileManager.copyItem(
            at: stagingDirectory,
            to: newDatasetDirectory
        )

        if fileManager.fileExists(
            atPath: datasetDirectory.path
        ) {
            try fileManager.removeItem(
                at: datasetDirectory
            )
        }

        try fileManager.moveItem(
            at: newDatasetDirectory,
            to: datasetDirectory
        )

        DatasetVersionStore().save(
            version: metadata.version,
            fareDataUpdatedAt:
                metadata.fareDataUpdatedAt
        )

        print("Dataset installed at:")
        print(datasetDirectory.path)
    }
}
