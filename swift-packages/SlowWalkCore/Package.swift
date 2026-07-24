// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SlowWalkCore",
    products: [
        .library(name: "SlowWalkDomain", targets: ["SlowWalkDomain"]),
        .library(name: "SlowWalkRiskEngine", targets: ["SlowWalkRiskEngine"]),
        .library(name: "SlowWalkAPIContracts", targets: ["SlowWalkAPIContracts"]),
        .library(name: "SlowWalkDataInterfaces", targets: ["SlowWalkDataInterfaces"]),
        .library(
            name: "SlowWalkMedicinePipeline",
            targets: ["SlowWalkMedicinePipeline"]
        ),
        .library(
            name: "SlowWalkMedicineKnowledge",
            targets: ["SlowWalkMedicineKnowledge"]
        ),
    ],
    targets: [
        .target(name: "SlowWalkDomain"),
        .target(
            name: "SlowWalkRiskEngine",
            dependencies: ["SlowWalkDomain"]
        ),
        .target(
            name: "SlowWalkAPIContracts",
            dependencies: [
                "SlowWalkDomain",
                "SlowWalkMedicineKnowledge",
            ]
        ),
        .target(
            name: "SlowWalkDataInterfaces",
            dependencies: ["SlowWalkDomain"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "SlowWalkMedicineKnowledge",
            dependencies: [
                "SlowWalkDomain",
                "SlowWalkDataInterfaces",
            ]
        ),
        .target(
            name: "SlowWalkMedicinePipeline",
            dependencies: [
                "SlowWalkDomain",
                "SlowWalkRiskEngine",
                "SlowWalkDataInterfaces",
                "SlowWalkMedicineKnowledge",
            ]
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
            dependencies: [
                "SlowWalkDomain",
                "SlowWalkMedicineKnowledge",
                "SlowWalkAPIContracts",
            ]
        ),
        .testTarget(
            name: "SlowWalkDataInterfacesTests",
            dependencies: ["SlowWalkDomain", "SlowWalkDataInterfaces"]
        ),
        .testTarget(
            name: "SlowWalkMedicineKnowledgeTests",
            dependencies: [
                "SlowWalkDomain",
                "SlowWalkDataInterfaces",
                "SlowWalkMedicineKnowledge",
            ],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "SlowWalkMedicinePipelineTests",
            dependencies: [
                "SlowWalkDomain",
                "SlowWalkRiskEngine",
                "SlowWalkDataInterfaces",
                "SlowWalkMedicineKnowledge",
                "SlowWalkMedicinePipeline",
            ]
        ),
    ]
)
