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

    func testShortStationaryTrackCannotBeGreenProgress()
        throws
    {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: [
                sample(longitude: 20.005, age: 120),
                sample(longitude: 20.005, age: 60),
                sample(longitude: 20.005, age: 0),
            ]
        )

        XCTAssertEqual(assessment.level, .yellow)
        XCTAssertFalse(
            assessment.reasons.contains {
                $0.code == .progressingTowardDestination
            }
        )
        XCTAssertTrue(
            assessment.reasons.contains {
                $0.code == .locationTrendIndeterminate
            }
        )
    }

    func testLateralMovementCannotBeGreenProgress()
        throws
    {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: [
                sample(
                    latitude: 10.001,
                    longitude: 20.005,
                    age: 120
                ),
                sample(
                    latitude: 10,
                    longitude: 20.005,
                    age: 60
                ),
                sample(
                    latitude: 9.999,
                    longitude: 20.005,
                    age: 0
                ),
            ]
        )

        XCTAssertEqual(assessment.level, .yellow)
        XCTAssertFalse(
            assessment.reasons.contains {
                $0.code == .progressingTowardDestination
            }
        )
    }

    func testExplicitDecreasingDistanceTrendIsGreen()
        throws
    {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: [
                sample(longitude: 20.007, age: 240),
                sample(longitude: 20.005, age: 120),
                sample(longitude: 20.003, age: 0),
            ]
        )

        XCTAssertEqual(assessment.level, .green)
        XCTAssertTrue(
            assessment.reasons.contains {
                $0.code == .progressingTowardDestination
            }
        )
    }

    func testApproachingTrendUsesSpecificReasonAndCopy()
        throws
    {
        let assessment = try engine.assess(
            destination: destination,
            recentSamples: [
                sample(longitude: 20.0020, age: 120),
                sample(longitude: 20.0015, age: 60),
                sample(longitude: 20.0010, age: 0),
            ]
        )
        let card = LocationActionCardFactory()
            .makeCard(from: assessment)

        XCTAssertEqual(assessment.level, .green)
        XCTAssertTrue(
            assessment.reasons.contains {
                $0.code == .approachingDestination
            }
        )
        XCTAssertEqual(card.title, "正在接近目的地")
        XCTAssertFalse(card.title.contains("到达"))
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
        let card = LocationActionCardFactory()
            .makeCard(from: assessment)
        XCTAssertEqual(card.title, "已到达目的地范围")
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

    func testTwoDataQualityOrangeReasonsCannotProduceRed()
        throws
    {
        let quality = LocationDataQuality(
            status: .invalid,
            accuracy: .good,
            issues: [
                qualityIssue(
                    code: .samplesOutOfOrder,
                    rule: "test-order"
                ),
                qualityIssue(
                    code: .implausibleJump,
                    rule: "test-jump"
                ),
            ],
            usableSampleIndices: [0, 1, 2],
            configurationNotices:
                LocationRiskConfiguration.notices
        )
        let assessment = try engine(
            quality: quality
        ).assess(
            destination: destination,
            recentSamples: [
                sample(longitude: 20.005, age: 120),
                sample(longitude: 20.005, age: 60),
                sample(longitude: 20.005, age: 0),
            ]
        )

        XCTAssertEqual(assessment.level, .orange)
        XCTAssertFalse(assessment.requiresFamilyAttention)
        XCTAssertFalse(
            assessment.reasons.contains {
                $0.code == .multipleHighRiskSignals
            }
        )
    }

    func testQualityOrangePlusOneBehaviorIsNotTwoBehaviors()
        throws
    {
        let quality = LocationDataQuality(
            status: .invalid,
            accuracy: .good,
            issues: [
                qualityIssue(
                    code: .implausibleJump,
                    rule: "test-jump"
                ),
            ],
            usableSampleIndices: [0, 1, 2],
            configurationNotices:
                LocationRiskConfiguration.notices
        )
        let assessment = try engine(
            quality: quality
        ).assess(
            destination: destination,
            recentSamples: prolongedStopSamples
        )

        XCTAssertEqual(assessment.level, .orange)
        XCTAssertTrue(
            assessment.reasons.contains {
                $0.code == .prolongedStop
            }
        )
        XCTAssertFalse(assessment.requiresFamilyAttention)
        XCTAssertFalse(
            assessment.reasons.contains {
                $0.code == .multipleHighRiskSignals
            }
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
            "检测到多个独立行为风险，请停在安全位置并联系家属或工作人员。"
        )
        XCTAssertFalse(
            card.recommendedActions.contains(
                .continueTowardDestination
            )
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

    private func engine(
        quality: LocationDataQuality
    ) -> LocationRiskEngine {
        LocationRiskEngine(
            clock: LocationTestClock(date: now),
            dataQualityAssessor:
                FixedLocationDataQualityAssessor(
                    result: quality
                )
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

    private func qualityIssue(
        code: LocationDataQualityIssueCode,
        rule: String
    ) -> LocationDataQualityIssue {
        LocationDataQualityIssue(
            code: code,
            message: "Test data-quality issue.",
            sampleIndex: 1,
            severity: .error,
            ruleIdentifier: rule
        )
    }
}

private struct LocationTestClock: Clock, Sendable {
    let date: Date

    func now() -> Date {
        date
    }
}

private struct FixedLocationDataQualityAssessor:
    LocationDataQualityAssessing,
    Sendable
{
    let result: LocationDataQuality

    func assess(
        samples: [LocationSample],
        relativeTo referenceDate: Date
    ) -> LocationDataQuality {
        result
    }
}
