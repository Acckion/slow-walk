import Foundation
import SlowWalkDomain
@testable import SlowWalkLocationRisk
import XCTest

final class LocationRiskCoreTests: XCTestCase {
    private let now = Date(
        timeIntervalSince1970: 1_784_980_800
    )

    func testSamePointDistanceIsZero() throws {
        let point = GeoPoint(
            latitude: 10,
            longitude: 20
        )
        XCTAssertEqual(
            try HaversineDistanceCalculator()
                .distance(from: point, to: point),
            0
        )
    }

    func testKnownShortDistanceUsesMeters() throws {
        let distance = try HaversineDistanceCalculator()
            .distance(
                from: GeoPoint(
                    latitude: 0,
                    longitude: 0
                ),
                to: GeoPoint(
                    latitude: 0,
                    longitude: 0.001
                )
            )
        XCTAssertEqual(distance, 111.19, accuracy: 0.5)
    }

    func testLongitudeBoundaryUsesShortestArc() throws {
        let distance = try HaversineDistanceCalculator()
            .distance(
                from: GeoPoint(
                    latitude: 0,
                    longitude: 179.999
                ),
                to: GeoPoint(
                    latitude: 0,
                    longitude: -179.999
                )
            )
        XCTAssertEqual(distance, 222.39, accuracy: 1)
    }

    func testDistanceRejectsInvalidLatitude() {
        XCTAssertThrowsError(
            try HaversineDistanceCalculator()
                .distance(
                    from: GeoPoint(
                        latitude: 91,
                        longitude: 20
                    ),
                    to: destination.point
                )
        ) {
            XCTAssertEqual(
                $0 as? DistanceCalculationError,
                .latitudeOutOfRange
            )
        }
    }

    func testDistanceRejectsInvalidLongitude() {
        XCTAssertThrowsError(
            try HaversineDistanceCalculator()
                .distance(
                    from: GeoPoint(
                        latitude: 10,
                        longitude: 181
                    ),
                    to: destination.point
                )
        ) {
            XCTAssertEqual(
                $0 as? DistanceCalculationError,
                .longitudeOutOfRange
            )
        }
    }

    func testDistanceRejectsNonFiniteCoordinate() {
        XCTAssertThrowsError(
            try HaversineDistanceCalculator()
                .distance(
                    from: GeoPoint(
                        latitude: .nan,
                        longitude: 20
                    ),
                    to: destination.point
                )
        ) {
            XCTAssertEqual(
                $0 as? DistanceCalculationError,
                .nonFiniteCoordinate
            )
        }
    }

    func testFutureSampleIsInvalid() {
        let quality = assessor.assess(
            samples: [
                sample(age: -60),
                sample(age: 0),
            ],
            relativeTo: now
        )
        XCTAssertEqual(quality.status, .invalid)
        XCTAssertTrue(
            quality.issues.contains {
                $0.code == .futureSample
            }
        )
    }

    func testStaleSamplesAreInsufficient() {
        let quality = assessor.assess(
            samples: [
                sample(age: 2_000),
                sample(age: 1_900),
            ],
            relativeTo: now
        )
        XCTAssertEqual(quality.status, .insufficient)
        XCTAssertEqual(quality.usableSampleIndices, [])
        XCTAssertTrue(
            quality.issues.contains {
                $0.code == .staleSample
            }
        )
    }

    func testLowAccuracySamplesAreInsufficient() {
        let quality = assessor.assess(
            samples: [
                sample(age: 60, accuracy: 500),
                sample(age: 0, accuracy: 500),
            ],
            relativeTo: now
        )
        XCTAssertEqual(quality.status, .insufficient)
        XCTAssertEqual(quality.accuracy, .insufficient)
    }

    func testMissingAccuracyIsReported() {
        let quality = assessor.assess(
            samples: [
                sample(age: 60, accuracy: nil),
                sample(age: 0),
            ],
            relativeTo: now
        )
        XCTAssertTrue(
            quality.issues.contains {
                $0.code == .accuracyMissing
            }
        )
        XCTAssertNotEqual(quality.status, .valid)
    }

    func testNegativeAccuracyIsInvalid() {
        let quality = assessor.assess(
            samples: [
                sample(age: 60, accuracy: -1),
                sample(age: 0),
            ],
            relativeTo: now
        )
        XCTAssertEqual(quality.status, .invalid)
        XCTAssertTrue(
            quality.issues.contains {
                $0.code == .accuracyInvalid
            }
        )
    }

    func testOutOfOrderSamplesAreInvalid() {
        let quality = assessor.assess(
            samples: [
                sample(age: 0),
                sample(age: 60),
            ],
            relativeTo: now
        )
        XCTAssertEqual(quality.status, .invalid)
        XCTAssertTrue(
            quality.issues.contains {
                $0.code == .samplesOutOfOrder
            }
        )
    }

    func testImplausibleJumpIsExcluded() {
        let quality = assessor.assess(
            samples: [
                sample(
                    latitude: 10,
                    longitude: 20,
                    age: 1
                ),
                sample(
                    latitude: 11,
                    longitude: 21,
                    age: 0
                ),
            ],
            relativeTo: now
        )
        XCTAssertTrue(
            quality.issues.contains {
                $0.code == .implausibleJump
            }
        )
        XCTAssertEqual(quality.usableSampleIndices, [0])
        XCTAssertNotEqual(quality.status, .valid)
    }

    func testInsufficientSampleCountCannotBeValid() {
        let quality = assessor.assess(
            samples: [sample(age: 0)],
            relativeTo: now
        )
        XCTAssertEqual(quality.status, .insufficient)
        XCTAssertTrue(
            quality.issues.contains {
                $0.code == .insufficientSamples
            }
        )
    }

    func testGeofenceOutside() {
        XCTAssertEqual(
            GeofenceEvaluator().evaluate(
                distanceMeters: 250,
                destinationRadiusMeters: 50
            ),
            .outside
        )
    }

    func testGeofenceApproaching() {
        XCTAssertEqual(
            GeofenceEvaluator().evaluate(
                distanceMeters: 150,
                destinationRadiusMeters: 50
            ),
            .approaching
        )
    }

    func testGeofenceInsideIncludesBoundary() {
        XCTAssertEqual(
            GeofenceEvaluator().evaluate(
                distanceMeters: 50,
                destinationRadiusMeters: 50
            ),
            .inside
        )
    }

    func testShortOrdinaryStopIsNotEmergency() {
        let result = ProlongedStopEvaluator().evaluate(
            samples: [
                sample(longitude: 20.01, age: 60),
                sample(longitude: 20.01001, age: 30),
                sample(longitude: 20.01, age: 0),
            ],
            destination: destination
        )
        XCTAssertFalse(result.isDetected)
        XCTAssertFalse(result.isDeterminate)
    }

    func testProlongedStopIsDetectedAwayFromDestination() {
        let result = ProlongedStopEvaluator().evaluate(
            samples: prolongedStopSamples,
            destination: destination
        )
        XCTAssertTrue(result.isDetected)
        XCTAssertTrue(result.isDeterminate)
        XCTAssertGreaterThanOrEqual(
            result.durationSeconds,
            600
        )
    }

    func testTooFewSamplesCannotDetermineStop() {
        let result = ProlongedStopEvaluator().evaluate(
            samples: [
                sample(longitude: 20.01, age: 900),
                sample(longitude: 20.01, age: 0),
            ],
            destination: destination
        )
        XCTAssertFalse(result.isDetected)
        XCTAssertFalse(result.isDeterminate)
    }

    func testNormalProgressDoesNotTriggerMovingAway() {
        let result = MovingAwayEvaluator().evaluate(
            samples: [
                sample(longitude: 20.007, age: 240),
                sample(longitude: 20.005, age: 120),
                sample(longitude: 20.003, age: 0),
            ],
            destination: destination
        )
        XCTAssertFalse(result.isDetected)
        XCTAssertTrue(result.isDeterminate)
    }

    func testSustainedMovingAwayIsDetected() {
        let result = MovingAwayEvaluator().evaluate(
            samples: movingAwaySamples,
            destination: destination
        )
        XCTAssertTrue(result.isDetected)
        XCTAssertTrue(result.isDeterminate)
        XCTAssertEqual(result.consecutiveIncreases, 2)
    }

    func testSingleMoveAwayCannotTrigger() {
        let result = MovingAwayEvaluator().evaluate(
            samples: [
                sample(longitude: 20.005, age: 180),
                sample(longitude: 20.006, age: 0),
            ],
            destination: destination
        )
        XCTAssertFalse(result.isDetected)
        XCTAssertFalse(result.isDeterminate)
    }

    func testGPSNoiseDoesNotTriggerMovingAway() {
        let result = MovingAwayEvaluator().evaluate(
            samples: [
                sample(longitude: 20.00500, age: 240),
                sample(longitude: 20.00501, age: 120),
                sample(longitude: 20.00502, age: 0),
            ],
            destination: destination
        )
        XCTAssertFalse(result.isDetected)
        XCTAssertTrue(result.isDeterminate)
    }

    func testInsufficientDataNeverProducesGreen() throws {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: [sample(age: 0)]
        )
        XCTAssertEqual(assessment.level, .yellow)
        XCTAssertTrue(assessment.requiresUserAttention)
    }

    func testArrivedWithReliableHistoryIsGreen() throws {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: [
                sample(longitude: 20.0002, age: 60),
                sample(longitude: 20.0001, age: 0),
            ]
        )
        XCTAssertEqual(assessment.level, .green)
        XCTAssertTrue(
            assessment.isInsideDestinationGeofence
        )
        XCTAssertEqual(
            assessment.recommendedActions,
            [.confirmArrival]
        )
    }

    func testProlongedStopProducesOrangeNotRed() throws {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: prolongedStopSamples
        )
        XCTAssertEqual(assessment.level, .orange)
        XCTAssertFalse(assessment.requiresFamilyAttention)
        XCTAssertTrue(
            assessment.reasons.contains {
                $0.code == .prolongedStop
            }
        )
    }

    func testMultipleRulesUseHighestRedLevel() throws {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: combinedRiskSamples
        )
        XCTAssertEqual(assessment.level, .red)
        XCTAssertTrue(assessment.requiresFamilyAttention)
        XCTAssertTrue(
            assessment.reasons.contains {
                $0.code == .prolongedStop
            }
        )
        XCTAssertTrue(
            assessment.reasons.contains {
                $0.code == .movingAway
            }
        )
        XCTAssertFalse(
            assessment.recommendedActions.contains(
                .continueTowardDestination
            )
        )
    }

    func testReasonOrderingAndOutputAreDeterministic()
        throws {
        let first = try engine.assess(
            destination: destination,
            recentSamples: combinedRiskSamples
        )
        let second = try engine.assess(
            destination: destination,
            recentSamples: combinedRiskSamples
        )
        XCTAssertEqual(first, second)
        XCTAssertEqual(
            first.reasons.map(\.code.rawValue),
            first.reasons.map(\.code.rawValue).sorted()
        )
    }

    func testActionCardPreservesRedSafetyBoundary()
        throws {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: combinedRiskSamples
        )
        let card = LocationActionCardFactory()
            .makeCard(from: assessment)
        XCTAssertEqual(card.riskLevel, .red)
        XCTAssertEqual(
            card.primaryInstruction,
            "当前出现多项高风险位置异常，建议联系家属或工作人员。"
        )
        XCTAssertTrue(
            card.warnings.contains(
                "DEMO LOCATION SAFETY CONFIGURATION"
            )
        )
        XCTAssertTrue(
            card.warnings.contains(
                "NOT A PRODUCTION NAVIGATION STANDARD"
            )
        )
    }

    private var assessor: LocationDataQualityAssessor {
        LocationDataQualityAssessor()
    }

    private var engine: LocationRiskEngine {
        LocationRiskEngine(
            clock: LocationTestClock(date: now)
        )
    }

    private var destination: Destination {
        Destination(
            id: "demo-destination",
            name: "虚构目的地",
            point: GeoPoint(
                latitude: 10,
                longitude: 20
            ),
            geofenceRadiusMeters: 50
        )
    }

    private var prolongedStopSamples: [LocationSample] {
        [
            sample(longitude: 20.01000, age: 900),
            sample(longitude: 20.01001, age: 450),
            sample(longitude: 20.01000, age: 0),
        ]
    }

    private var movingAwaySamples: [LocationSample] {
        [
            sample(longitude: 20.005, age: 240),
            sample(longitude: 20.006, age: 120),
            sample(longitude: 20.007, age: 0),
        ]
    }

    private var combinedRiskSamples: [LocationSample] {
        [
            sample(longitude: 20.01000, age: 900),
            sample(longitude: 20.01015, age: 450),
            sample(longitude: 20.01035, age: 0),
        ]
    }

    private func sample(
        latitude: Double = 10,
        longitude: Double = 20,
        age: TimeInterval,
        accuracy: Double? = 10
    ) -> LocationSample {
        LocationSample(
            point: GeoPoint(
                latitude: latitude,
                longitude: longitude
            ),
            recordedAt: now.addingTimeInterval(-age),
            horizontalAccuracyMeters: accuracy,
            speedMetersPerSecond: nil,
            source: "demo"
        )
    }
}

private struct LocationTestClock: Clock, Sendable {
    let date: Date

    func now() -> Date {
        date
    }
}
