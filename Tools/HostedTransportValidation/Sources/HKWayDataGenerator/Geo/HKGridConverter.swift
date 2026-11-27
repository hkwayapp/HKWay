//
//  HKGridConverter.swift
//  HK Way
//
//  Created by Ken on 9/8/2026.
//

import Foundation

struct Coordinate {
    let latitude: Double
    let longitude: Double
}

struct HKGridConverter {

    func convert(easting: Double, northing: Double) -> Coordinate {
        // Hong Kong 1980 Grid / Transverse Mercator
        let a = 6378388.0
        let b = 6356911.9461279465
        let originLatitude = 22.31213333333334 * Double.pi / 180.0
        let centralMeridian = 114.1785555555556 * Double.pi / 180.0
        let falseEasting = 836694.05
        let falseNorthing = 819069.80
        let scaleFactor = 1.0

        let e = sqrt(1.0 - (b * b) / (a * a))
        let ePrimeSquared = (a * a - b * b) / (b * b)

        let x = easting - falseEasting
        let y = northing - falseNorthing

        let meridionalArc = meridionalArcAtLatitude(
            originLatitude,
            a: a,
            eSquared: e * e
        )

        let m = meridionalArc + y / scaleFactor

        let mu = m / (
            a * (
                1.0
                - e * e / 4.0
                - 3.0 * pow(e, 4) / 64.0
                - 5.0 * pow(e, 6) / 256.0
            )
        )

        let e1 = (
            1.0 - sqrt(1.0 - e * e)
        ) / (
            1.0 + sqrt(1.0 - e * e)
        )

        let phi1 = mu
            + (3.0 * e1 / 2.0 - 27.0 * pow(e1, 3) / 32.0) * sin(2.0 * mu)
            + (21.0 * pow(e1, 2) / 16.0 - 55.0 * pow(e1, 4) / 32.0) * sin(4.0 * mu)
            + (151.0 * pow(e1, 3) / 96.0) * sin(6.0 * mu)
            + (1097.0 * pow(e1, 4) / 512.0) * sin(8.0 * mu)

        let sinPhi1 = sin(phi1)
        let cosPhi1 = cos(phi1)

        let n1 = a / sqrt(1.0 - e * e * sinPhi1 * sinPhi1)
        let t1 = tan(phi1) * tan(phi1)
        let c1 = ePrimeSquared * cosPhi1 * cosPhi1
        let r1 = a * (1.0 - e * e) /
            pow(1.0 - e * e * sinPhi1 * sinPhi1, 1.5)

        let d = x / (n1 * scaleFactor)

        let latitude = phi1 - (
            n1 * tan(phi1) / r1
        ) * (
            d * d / 2.0
            - (5.0 + 3.0 * t1 + 10.0 * c1 - 4.0 * c1 * c1 - 9.0 * ePrimeSquared)
                * pow(d, 4) / 24.0
            + (61.0 + 90.0 * t1 + 298.0 * c1 + 45.0 * t1 * t1
               - 252.0 * ePrimeSquared - 3.0 * c1 * c1)
                * pow(d, 6) / 720.0
        )

        let longitude = centralMeridian + (
            d
            - (1.0 + 2.0 * t1 + c1) * pow(d, 3) / 6.0
            + (5.0 - 2.0 * c1 + 28.0 * t1 - 3.0 * c1 * c1
               + 8.0 * ePrimeSquared + 24.0 * t1 * t1)
                * pow(d, 5) / 120.0
        ) / cosPhi1

        return Coordinate(
            latitude: latitude * 180.0 / Double.pi,
            longitude: longitude * 180.0 / Double.pi
        )
    }

    private func meridionalArcAtLatitude(
        _ latitude: Double,
        a: Double,
        eSquared: Double
    ) -> Double {
        a * (
            (1.0 - eSquared / 4.0 - 3.0 * pow(eSquared, 2) / 64.0
             - 5.0 * pow(eSquared, 3) / 256.0) * latitude
            - (3.0 * eSquared / 8.0
               + 3.0 * pow(eSquared, 2) / 32.0
               + 45.0 * pow(eSquared, 3) / 1024.0) * sin(2.0 * latitude)
            + (15.0 * pow(eSquared, 2) / 256.0
               + 45.0 * pow(eSquared, 3) / 1024.0) * sin(4.0 * latitude)
            - (35.0 * pow(eSquared, 3) / 3072.0) * sin(6.0 * latitude)
        )
    }
}
