//
//  JourneyShapeStore.swift
//  HK Way
//

import Foundation

actor JourneyShapeStore {

    static let shared = JourneyShapeStore()

    private var shapesByJourneyId:
        [String: TransitJourneyShape]?

    func shape(
        for journeyId: String
    ) throws -> TransitJourneyShape? {

        if shapesByJourneyId == nil {
            try loadShapes()
        }

        return shapesByJourneyId?[journeyId]
    }

    private func loadShapes() throws {

        let url = try DatasetStorage().fileURL(
            for: .journeyShapes
        )
        let shapes = try JSONDecoder().decode(
            [TransitJourneyShape].self,
            from: Data(contentsOf: url)
        )

        shapesByJourneyId = Dictionary(
            uniqueKeysWithValues: shapes.map {
                ($0.journeyId, $0)
            }
        )
    }
}
