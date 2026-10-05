//
//  TransitDataService.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct TransitDataService {

    let routeReader = RouteReader()
    let journeyReader = JourneyReader()
    let journeyStopReader = JourneyStopReader()
    let stopReader = StopReader()
    let scheduleReader = ScheduleReader()

    func getJourneyDetail(
        journeyId: String
    ) throws {

        let journeys = try journeyReader.read()

        guard let journey = journeys.first(
            where: { $0.id == journeyId }
        ) else {
            print("Journey not found")
            return
        }

        print("Journey: \(journey.id)")

        let journeyStops = try journeyStopReader.read()
            .filter {
                $0.journeyId == journey.id
            }
            .sorted {
                $0.sequence < $1.sequence
            }


        let stops = try stopReader.read()


        print("Stops:")

        for item in journeyStops {

            if let stop = stops.first(
                where: { $0.id == item.stopId }
            ) {
                print(
                    "\(item.sequence). \(stop.nameEnglish)"
                )
            }
        }


        let schedules = try scheduleReader.read()
            .filter {
                $0.journeyId == journey.id
            }

        print("Schedules:")

        for schedule in schedules {
            print(schedule.departureTime)
        }
    }
}
