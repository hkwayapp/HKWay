//
//  DataBuilder.swift
//  HKWayDataGenerator
//
//  Created by Ken on 7/8/2026.
//

import Foundation

struct DataBuilder {
    
    let operatorBuilder: OperatorBuilder
    let routeBuilder: RouteBuilder
    let journeyBuilder: JourneyBuilder
    let journeyStopBuilder: JourneyStopBuilder
    let stopBuilder: StopBuilder
    let scheduleBuilder: ScheduleBuilder
    let validator: MasterDataValidating
    
    init(
        operatorBuilder: OperatorBuilder = OperatorBuilder(),
        routeBuilder: RouteBuilder = RouteBuilder(),
        journeyBuilder: JourneyBuilder = JourneyBuilder(),
        journeyStopBuilder: JourneyStopBuilder = JourneyStopBuilder(),
        stopBuilder: StopBuilder = StopBuilder(),
        scheduleBuilder: ScheduleBuilder = ScheduleBuilder(),
        validator: MasterDataValidating = MasterDataValidator()
    ) {
        self.operatorBuilder = operatorBuilder
        self.routeBuilder = routeBuilder
        self.journeyBuilder = journeyBuilder
        self.journeyStopBuilder = journeyStopBuilder
        self.stopBuilder = stopBuilder
        self.scheduleBuilder = scheduleBuilder
        self.validator = validator
    }

    func build() throws -> MasterData {

        let masterData = MasterData(
            operators: try operatorBuilder.build(),
            routes: try routeBuilder.build(),
            journeys: try journeyBuilder.build(),
            journeyStops: try journeyStopBuilder.build(),
            stops: try stopBuilder.build(),
            schedules: try scheduleBuilder.build(),
            operatorStopReferences: []
        )

        try validator.validate(masterData)

        return masterData
    }

}
