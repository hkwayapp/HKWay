//
//  RawTransportService.swift
//  HK Way
//
//  Created by Ken on 7/8/2026.
//

import Foundation

public struct RawTransportService: Codable {

    public let routeId: String?
    public let routeNumber: String?

    public let operatorName: String?

    public let origin: String?
    public let destination: String?

    public let direction: String?

    public let serviceType: String?

    public let stops: [RawTransportStop]?

    public init(
        routeId: String?,
        routeNumber: String?,
        operatorName: String?,
        origin: String?,
        destination: String?,
        direction: String?,
        serviceType: String?,
        stops: [RawTransportStop]?
    ) {
        self.routeId = routeId
        self.routeNumber = routeNumber
        self.operatorName = operatorName
        self.origin = origin
        self.destination = destination
        self.direction = direction
        self.serviceType = serviceType
        self.stops = stops
    }
}
