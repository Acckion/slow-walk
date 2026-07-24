// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SlowWalkCore",
    products: [
        .library(name: "SlowWalkDomain", targets: ["SlowWalkDomain"]),
        .library(name: "SlowWalkRiskEngine", targets: ["SlowWalkRiskEngine"]),
        .library(name: "SlowWalkAPIContracts", targets: ["SlowWalkAPIContracts"]),
        .library(name: "SlowWalkDataInterfaces", targets: ["SlowWalkDataInterfaces"]),
    ],
    targets: [
        .target(name: "SlowWalkDomain"),
        .target(
            name: "SlowWalkRiskEngine",
            dependencies: ["SlowWalkDomain"]
        ),
        .target(
            name: "SlowWalkAPIContracts",
            dependencies: ["SlowWalkDomain"]
        ),
        .target(
            name: "SlowWalkDataInterfaces",
            dependencies: ["SlowWalkDomain"]
        ),
        .testTarget(
            name: "SlowWalkDomainTests",
            dependencies: ["SlowWalkDomain"]
        ),
        .testTarget(
            name: "SlowWalkRiskEngineTests",
            dependencies: ["SlowWalkDomain", "SlowWalkRiskEngine"]
        ),
        .testTarget(
            name: "SlowWalkAPIContractsTests",
            dependencies: ["SlowWalkDomain", "SlowWalkAPIContracts"]
        ),
        .testTarget(
            name: "SlowWalkDataInterfacesTests",
            dependencies: ["SlowWalkDomain", "SlowWalkDataInterfaces"]
        ),
    ]
)
