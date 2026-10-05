//
//  DatasetReader.swift
//  HK Way
//
//  Created by Ken on 11/8/2026.
//

import Foundation

struct DatasetReader {

    func decodeOperators(
        from fileURL: URL
    ) throws -> [TransitOperator] {

        let data = try Data(contentsOf: fileURL)

        return try JSONDecoder().decode(
            [TransitOperator].self,
            from: data
        )
    }

    func decodeRoutes(
        from fileURL: URL
    ) throws -> [TransitRoute] {

        let data = try Data(contentsOf: fileURL)

        return try JSONDecoder().decode(
            [TransitRoute].self,
            from: data
        )
    }

    func decodeStops(
        from fileURL: URL
    ) throws -> [TransitStop] {

        let data = try Data(contentsOf: fileURL)

        return try JSONDecoder().decode(
            [TransitStop].self,
            from: data
        )
    }

    func decodeJourneys(
        from fileURL: URL
    ) throws -> [TransitJourney] {

        let data = try Data(contentsOf: fileURL)

        return try JSONDecoder().decode(
            [TransitJourney].self,
            from: data
        )
    }

    func decodeJourneyStops(
        from fileURL: URL
    ) throws -> [TransitJourneyStop] {

        let data = try Data(contentsOf: fileURL)

        return try JSONDecoder().decode(
            [TransitJourneyStop].self,
            from: data
        )
    }

    func decodeSchedules(
        from fileURL: URL
    ) throws -> [TransitSchedule] {

        let data = try Data(contentsOf: fileURL)

        return try JSONDecoder().decode(
            [TransitSchedule].self,
            from: data
        )
    }

    func decodeOperatorStopReferences(
        from fileURL: URL
    ) throws -> [TransitOperatorStopReference] {

        let data = try Data(
            contentsOf: fileURL
        )

        return try JSONDecoder().decode(
            [TransitOperatorStopReference].self,
            from: data
        )
    }
}
