//
//  JourneyShapeBuilder.swift
//  HK Way
//

import Foundation

struct JourneyShapeBuilder {

    func build(
        journeys: [Journey],
        officialShapes: [CSDIBusRouteShape]
    ) -> [JourneyShape] {

        let shapesByKey = Dictionary(
            grouping: officialShapes,
            by: {
                key(
                    routeId: $0.routeId,
                    direction:
                        String($0.routeSequence)
                )
            }
        )

        return journeys.compactMap { journey in
            let candidates = shapesByKey[
                key(
                    routeId: journey.routeId,
                    direction: journey.direction
                ),
                default: []
            ]

            guard
                let winner = candidates.max(
                    by: {
                        coordinateCount($0) <
                            coordinateCount($1)
                    }
                )
            else {
                return nil
            }

            let coordinates = flatten(
                winner.segments
            )

            guard coordinates.count >= 2 else {
                return nil
            }

            return JourneyShape(
                journeyId: journey.id,
                coordinates: coordinates
            )
        }
        .sorted { $0.journeyId < $1.journeyId }
    }

    private func flatten(
        _ segments: [[JourneyShapeCoordinate]]
    ) -> [JourneyShapeCoordinate] {

        var result: [JourneyShapeCoordinate] = []

        for segment in segments where !segment.isEmpty {
            if result.last == segment.first {
                result.append(contentsOf: segment.dropFirst())
            } else {
                result.append(contentsOf: segment)
            }
        }

        return result
    }

    private func coordinateCount(
        _ shape: CSDIBusRouteShape
    ) -> Int {

        shape.segments.reduce(0) {
            $0 + $1.count
        }
    }

    private func key(
        routeId: String,
        direction: String
    ) -> String {

        routeId + "|" + direction
    }
}
