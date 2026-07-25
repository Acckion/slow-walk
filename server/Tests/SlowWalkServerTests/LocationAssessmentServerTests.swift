import Foundation
import Hummingbird
import HummingbirdTesting
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkLocationRisk
@testable import SlowWalkServer
import XCTest

final class LocationAssessmentServerTests:
    XCTestCase,
    @unchecked Sendable
{
    private let now = Date(
        timeIntervalSince1970: 1_784_980_800
    )

    func testNormalAssessment() async throws {
        try await assertAssessment(
            samples: normalProgressSamples,
            expectedLevel: .green
        ) {
            XCTAssertFalse(
                $0.assessment
                    .isInsideDestinationGeofence
            )
            XCTAssertEqual(
                $0.actionCard.recommendedActions,
                [.continueTowardDestination]
            )
            XCTAssertTrue(
                $0.assessment.reasons.contains {
                    $0.code
                        == .progressingTowardDestination
                }
            )
        }
    }

    func testArrivedAtDestination() async throws {
        try await assertAssessment(
            samples: [
                sample(longitude: 20.0002, age: 60),
                sample(longitude: 20.0001, age: 0),
            ],
            expectedLevel: .green
        ) {
            XCTAssertTrue(
                $0.assessment
                    .isInsideDestinationGeofence
            )
            XCTAssertEqual(
                $0.actionCard.recommendedActions,
                [.confirmArrival]
            )
            XCTAssertEqual(
                $0.actionCard.title,
                "已到达目的地范围"
            )
        }
    }

    func testApproachingRequiresDecreasingDistanceTrend()
        async throws
    {
        try await assertAssessment(
            samples: [
                sample(longitude: 20.0020, age: 120),
                sample(longitude: 20.0015, age: 60),
                sample(longitude: 20.0010, age: 0),
            ],
            expectedLevel: .green
        ) {
            XCTAssertTrue(
                $0.assessment.reasons.contains {
                    $0.code == .approachingDestination
                }
            )
            XCTAssertEqual(
                $0.actionCard.title,
                "正在接近目的地"
            )
        }
    }

    func testShortStationaryTrackIsNotGreenProgress()
        async throws
    {
        try await assertAssessment(
            samples: [
                sample(longitude: 20.005, age: 120),
                sample(longitude: 20.005, age: 60),
                sample(longitude: 20.005, age: 0),
            ],
            expectedLevel: .yellow
        ) {
            XCTAssertFalse(
                $0.assessment.reasons.contains {
                    $0.code
                        == .progressingTowardDestination
                }
            )
            XCTAssertTrue(
                $0.assessment.reasons.contains {
                    $0.code
                        == .locationTrendIndeterminate
                }
            )
        }
    }

    func testLateralTrackIsNotGreenProgress()
        async throws
    {
        try await assertAssessment(
            samples: [
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
            ],
            expectedLevel: .yellow
        ) {
            XCTAssertFalse(
                $0.assessment.reasons.contains {
                    $0.code
                        == .progressingTowardDestination
                }
            )
            XCTAssertEqual(
                $0.actionCard.title,
                "行进趋势无法确认"
            )
        }
    }

    func testLowAccuracyReturnsTypedError() async throws {
        try await assertError(
            request: makeRequest(
                samples: [
                    sample(age: 60, accuracy: 500),
                    sample(age: 0, accuracy: 500),
                ]
            ),
            expectedCode:
                .locationAccuracyInsufficient
        )
    }

    func testStaleDataReturnsTypedError() async throws {
        try await assertError(
            request: makeRequest(
                samples: [
                    sample(age: 2_000),
                    sample(age: 1_900),
                ]
            ),
            expectedCode: .locationDataStale
        )
    }

    func testProlongedStopIsOrange() async throws {
        try await assertAssessment(
            samples: prolongedStopSamples,
            expectedLevel: .orange
        ) {
            XCTAssertTrue(
                $0.assessment.reasons.contains {
                    $0.code == .prolongedStop
                }
            )
        }
    }

    func testMovingAwayIsOrange() async throws {
        try await assertAssessment(
            samples: movingAwaySamples,
            expectedLevel: .orange
        ) {
            XCTAssertTrue(
                $0.assessment.reasons.contains {
                    $0.code == .movingAway
                }
            )
        }
    }

    func testInvalidCoordinateReturnsTypedError()
        async throws {
        try await assertError(
            request: makeRequest(
                samples: [
                    sample(
                        latitude: 100,
                        age: 60
                    ),
                    sample(age: 0),
                ]
            ),
            expectedCode: .invalidLocationSample
        )
    }

    func testInsufficientHistoryReturnsTypedError()
        async throws {
        try await assertError(
            request: makeRequest(
                samples: [sample(age: 0)]
            ),
            expectedCode:
                .insufficientLocationHistory
        )
    }

    func testMalformedJSONReturnsTypedError()
        async throws {
        let application = try makeApplication()
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/location/assess",
                method: .post,
                headers: [
                    .contentType:
                        "application/json",
                ],
                body: ByteBuffer(
                    string: #"{"destination":"#
                )
            ) { response in
                XCTAssertEqual(
                    response.status,
                    .badRequest
                )
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(
                    error.code,
                    .malformedRequest
                )
                XCTAssertEqual(
                    error.requestID,
                    self.fallbackRequestID
                )
            }
        }
    }

    func testUnsupportedAPIVersionReturnsTypedError()
        async throws {
        try await assertError(
            request: makeRequest(
                samples: normalProgressSamples,
                apiVersion: "v2"
            ),
            expectedCode:
                .unsupportedAPIVersion,
            expectedStatus: .badRequest
        )
    }

    func testErrorDoesNotContainCompleteTrajectory()
        async throws {
        let request = makeRequest(
            samples: [
                sample(
                    latitude: 100,
                    longitude: 20.123456,
                    age: 60
                ),
                sample(
                    longitude: 20.654321,
                    age: 0
                ),
            ]
        )
        let application = try makeApplication()
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/location/assess",
                method: .post,
                headers: [
                    .contentType:
                        "application/json",
                ],
                body: try self.encode(request)
            ) { response in
                let body = String(
                    decoding:
                        response.body.readableBytesView,
                    as: UTF8.self
                )
                XCTAssertFalse(
                    body.contains("recentSamples")
                )
                XCTAssertFalse(
                    body.contains("20.123456")
                )
                XCTAssertFalse(
                    body.contains("20.654321")
                )
            }
        }
    }

    func testRedResultOverridesNormalNavigationPrompt()
        async throws {
        try await assertAssessment(
            samples: combinedRiskSamples,
            expectedLevel: .red
        ) {
            XCTAssertFalse(
                $0.actionCard.recommendedActions
                    .contains(
                        .continueTowardDestination
                    )
            )
            XCTAssertEqual(
                $0.actionCard.primaryInstruction,
                "检测到多个独立行为风险，请停在安全位置并联系家属或工作人员。"
            )
            XCTAssertTrue(
                $0.assessment.requiresFamilyAttention
            )
        }
    }

    private func assertAssessment(
        samples: [LocationSample],
        expectedLevel: RiskLevel,
        verify:
            @escaping @Sendable (
                LocationAssessmentResponseDTO
            ) throws -> Void = { _ in }
    ) async throws {
        let request = makeRequest(samples: samples)
        let application = try makeApplication()
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/location/assess",
                method: .post,
                headers: [
                    .contentType:
                        "application/json",
                ],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let output = try self.decode(
                    LocationAssessmentResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(
                    output.requestID,
                    self.requestID
                )
                XCTAssertEqual(
                    output.assessment.level,
                    expectedLevel
                )
                XCTAssertEqual(
                    output.actionCard.riskLevel,
                    expectedLevel
                )
                XCTAssertEqual(output.generatedAt, self.now)
                XCTAssertEqual(
                    output.apiVersion,
                    SlowWalkAPI.version
                )
                XCTAssertTrue(
                    output.warnings.contains(
                        "DEMO LOCATION SAFETY CONFIGURATION"
                    )
                )
                try verify(output)
            }
        }
    }

    private func assertError(
        request: LocationAssessmentRequestDTO,
        expectedCode: APIErrorCode,
        expectedStatus: HTTPResponse.Status =
            .unprocessableContent
    ) async throws {
        let application = try makeApplication()
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/location/assess",
                method: .post,
                headers: [
                    .contentType:
                        "application/json",
                ],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(
                    response.status,
                    expectedStatus
                )
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, expectedCode)
                XCTAssertEqual(
                    error.requestID,
                    self.requestID
                )
            }
        }
    }

    private func makeApplication()
        throws -> some ApplicationProtocol {
        try makeSlowWalkApplication(
            configuration: .init(port: 0),
            dateProvider: FixedDateProvider(
                fixedDate: now
            ),
            uuidProvider: FixedUUIDProvider(
                fixedUUID: fallbackRequestID
            )
        )
    }

    private func makeRequest(
        samples: [LocationSample],
        apiVersion: String = SlowWalkAPI.version
    ) -> LocationAssessmentRequestDTO {
        LocationAssessmentRequestDTO(
            destination: destination,
            recentSamples: samples,
            requestID: requestID,
            apiVersion: apiVersion
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

    private var normalProgressSamples: [LocationSample] {
        [
            sample(longitude: 20.007, age: 240),
            sample(longitude: 20.005, age: 120),
            sample(longitude: 20.003, age: 0),
        ]
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

    private func encode<Value: Encodable>(
        _ value: Value
    ) throws -> ByteBuffer {
        ByteBuffer(
            bytes: try SlowWalkJSONCoding.makeEncoder()
                .encode(value)
        )
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from buffer: ByteBuffer
    ) throws -> Value {
        try SlowWalkJSONCoding.makeDecoder()
            .decode(
                type,
                from: Data(
                    buffer.readableBytesView
                )
            )
    }

    private var requestID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 81
            )
        )
    }

    private var fallbackRequestID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 82
            )
        )
    }
}
