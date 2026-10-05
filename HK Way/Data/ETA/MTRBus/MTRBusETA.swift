//
//  MTRBusETA.swift
//  HK Way
//

import Foundation

struct MTRBusETAResponse: Decodable {
    let status: String
    let routeName: String
    let busStop: [MTRBusETAStop]
    let footerRemarks: String?
}

struct MTRBusETAStop: Decodable {
    let busStopId: String
    let isSuspended: String
    let bus: [MTRBusETA]
}

struct MTRBusETA: Decodable {
    let arrivalTimeInSecond: String
    let arrivalTimeText: String
    let departureTimeInSecond: String
    let departureTimeText: String
    let isScheduled: String
    let lineRef: String
}
