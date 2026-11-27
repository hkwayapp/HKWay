//
//  MasterData.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

struct MasterData: Codable {

    let operators: [Operator]
    let routes: [Route]
    let journeys: [Journey]
    let journeyStops: [JourneyStop]
    let stops: [Stop]
    let schedules: [Schedule]

    let operatorStopReferences: [OperatorStopReference]
}
