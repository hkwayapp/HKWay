//
//  HKWayApp.swift
//  HK Way
//
//  Created by Ken on 10/8/2026.
//

import SwiftUI
import SwiftData

@main
struct HKWayApp: App {

    @State
    private var locationManager = AppLocationManager()

    @State
    private var purchaseManager = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .environment(purchaseManager)
                .task {
                    await purchaseManager.start()
                }
        }
        .modelContainer(
            for: [
                OperatorEntity.self,
                 RouteEntity.self,
                 StopEntity.self,
                 JourneyEntity.self,
                 JourneyStopEntity.self,
                 ScheduleEntity.self,
                 OperatorStopReferenceEntity.self
            ]
        )
    }
}
