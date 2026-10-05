// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HK Way",

    platforms: [
        .macOS(.v12)
    ],
    
    targets: [

        .executableTarget(
            name: "HKWayDataGenerator",
            resources: [
                .process("Resources")
            ]
        )
    ],

    swiftLanguageModes: [.v6]
)
