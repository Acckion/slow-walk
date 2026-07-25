// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SlowWalkServer",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SlowWalkServerKit",
            targets: ["SlowWalkServer"]
        ),
        .executable(
            name: "SlowWalkServer",
            targets: ["SlowWalkServerApp"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            from: "2.25.1"
        ),
        .package(path: "../swift-packages/SlowWalkCore"),
    ],
    targets: [
        .target(
            name: "SlowWalkServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "SlowWalkDomain", package: "SlowWalkCore"),
                .product(name: "SlowWalkRiskEngine", package: "SlowWalkCore"),
                .product(name: "SlowWalkAPIContracts", package: "SlowWalkCore"),
                .product(name: "SlowWalkDataInterfaces", package: "SlowWalkCore"),
                .product(
                    name: "SlowWalkLocationRisk",
                    package: "SlowWalkCore"
                ),
                .product(
                    name: "SlowWalkMedicineKnowledge",
                    package: "SlowWalkCore"
                ),
                .product(
                    name: "SlowWalkMedicinePipeline",
                    package: "SlowWalkCore"
                ),
            ]
        ),
        .executableTarget(
            name: "SlowWalkServerApp",
            dependencies: ["SlowWalkServer"]
        ),
        .testTarget(
            name: "SlowWalkServerTests",
            dependencies: [
                "SlowWalkServer",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "SlowWalkDomain", package: "SlowWalkCore"),
                .product(name: "SlowWalkAPIContracts", package: "SlowWalkCore"),
                .product(name: "SlowWalkDataInterfaces", package: "SlowWalkCore"),
                .product(
                    name: "SlowWalkLocationRisk",
                    package: "SlowWalkCore"
                ),
                .product(
                    name: "SlowWalkMedicineKnowledge",
                    package: "SlowWalkCore"
                ),
                .product(
                    name: "SlowWalkMedicinePipeline",
                    package: "SlowWalkCore"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
