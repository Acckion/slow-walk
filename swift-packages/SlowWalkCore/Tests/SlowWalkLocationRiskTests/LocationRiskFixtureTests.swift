import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
import SlowWalkLocationRisk
import XCTest

final class LocationRiskFixtureTests: XCTestCase {
    private let now = Date(
        timeIntervalSince1970: 1_784_980_800
    )

    func testEveryLocationFixtureDecodesAndUsesDemoData()
        throws {
        let expectedNames = [
            "location-arrived",
            "location-approaching",
            "location-low-accuracy",
            "location-stale",
            "location-prolonged-stop",
            "location-moving-away",
            "location-normal-progress",
            "location-invalid-coordinate",
        ]

        for name in expectedNames {
            let url = try XCTUnwrap(
                Bundle.module.url(
                    forResource: name,
                    withExtension: "json"
                ),
                "Missing fixture: \(name).json"
            )
            let fixture = try SlowWalkJSONCoding
                .makeDecoder()
                .decode(
                    LocationScenarioFixture.self,
                    from: Data(contentsOf: url)
                )
            XCTAssertEqual(
                fixture.disclaimer,
                LocationRiskConfiguration.notices
            )
            XCTAssertFalse(fixture.scenario.isEmpty)
            XCTAssertFalse(
                fixture.request.destination.id.isEmpty
            )
            XCTAssertTrue(
                fixture.expectedRiskLevel != nil
                    || fixture.expectedErrorCode != nil
            )
        }
    }

    func testSuccessfulFixturesProduceExpectedRiskLevels()
        throws {
        let names = [
            "location-arrived",
            "location-approaching",
            "location-prolonged-stop",
            "location-moving-away",
            "location-normal-progress",
        ]
        let engine = LocationRiskEngine(
            clock: FixtureClock(date: now)
        )

        for name in names {
            let fixture = try load(name)
            let assessment = try engine.assess(
                destination: fixture.request.destination,
                recentSamples:
                    fixture.request.recentSamples
            )
            XCTAssertEqual(
                assessment.level,
                fixture.expectedRiskLevel,
                "Unexpected risk for \(name).json"
            )
        }
    }

    private func load(
        _ name: String
    ) throws -> LocationScenarioFixture {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "json"
            )
        )
        return try SlowWalkJSONCoding.makeDecoder()
            .decode(
                LocationScenarioFixture.self,
                from: Data(contentsOf: url)
            )
    }
}

private struct LocationScenarioFixture: Decodable {
    let scenario: String
    let disclaimer: [String]
    let request: LocationAssessmentRequestDTO
    let expectedRiskLevel: LocationRiskLevel?
    let expectedErrorCode: String?
}

private struct FixtureClock: Clock, Sendable {
    let date: Date

    func now() -> Date {
        date
    }
}
