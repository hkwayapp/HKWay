//
//  RealJourneyBuilder.swift
//  HK Way
//
//  Created by Ken on 9/8/2026.
//

import Foundation

struct RealJourneyBuilder {

    private let routeReader = RouteBusXMLReader()
    private let rStopReader = RStopBusXMLReader()
    private let sectionFareReader = SectionFareReader()

    func build() throws -> [Journey] {
        let routeURL = try resourceURL(
            name: "ROUTE_BUS"
        )

        let rStopURL = try resourceURL(
            name: "RSTOP_BUS"
        )

        let routes = try routeReader.read(from: routeURL)
        let rStops = try rStopReader.read(from: rStopURL)
        let sectionFares = try sectionFareReader.read()

        let routeByID = Dictionary(
            routes.map { ($0.routeID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let grouped = Dictionary(
            grouping: rStops,
            by: {
                "\($0.routeID)|\($0.routeSequence)"
            }
        )

        var journeys: [Journey] = []

        for (key, stops) in grouped {
            let components = key.split(separator: "|")

            guard components.count == 2,
                  let routeSequence = Int(components[1]),
                  let route = routeByID[String(components[0])] else {
                continue
            }
            
            let orderedStops = stops.sorted {
                $0.stopSequence < $1.stopSequence
            }

            guard let firstStop = orderedStops.first,
                  let lastStop = orderedStops.last else {
                continue
            }

            let validStopSequences = Set(
                orderedStops.map(\.stopSequence)
            )
            let validSectionFareTiers = sectionFares[
                "\(route.routeID)-\(routeSequence)"
            ]?.filter {
                validStopSequences.contains(
                    $0.boardingStopSequence
                )
            }

            journeys.append(
                Journey(
                    id: "\(route.routeID)-\(routeSequence)",
                    routeId: route.routeID,
                    originStopId: firstStop.stopID,
                    destinationStopId: lastStop.stopID,
                    direction: String(routeSequence),
                    serviceType: route.serviceMode,
                    adultFullFareCents:
                        [
                            "KMB", "LWB", "CTB",
                            "KMB+CTB", "LWB+CTB"
                        ].contains(
                            route.companyCode
                        )
                        ? route.fullFareCents
                        : nil,
                    scheduledDurationMinutes:
                        route.journeyTimeMinutes,
                    sectionFareTiers:
                        validSectionFareTiers?.isEmpty == false
                        ? validSectionFareTiers
                        : nil
                )
            )
        }

        return journeys.sorted {
            $0.id < $1.id
        }
    }

    private func resourceURL(
        name: String
    ) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "xml"
        ) else {
            throw RealJourneyBuilderError.resourceNotFound(
                "\(name).xml"
            )
        }

        return url
    }
}

enum RealJourneyBuilderError: Error {
    case resourceNotFound(String)
}
