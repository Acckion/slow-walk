import Foundation
import Hummingbird
import HummingbirdTesting
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
import XCTest
@testable import SlowWalkServer

final class HealthContextServerTests:
    XCTestCase,
    @unchecked Sendable
{
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testCompleteHealthContextAssessmentSucceeds() async throws {
        let request = makeRequest()
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let output = try self.decode(
                    MedicineAssessmentResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(output.resolution.status, .resolved)
                XCTAssertEqual(output.assessment?.level, .green)
                XCTAssertEqual(output.actionCard.riskLevel, .green)
                XCTAssertEqual(
                    output.healthContextValidation?.status,
                    "valid"
                )
                XCTAssertEqual(
                    output.healthContextValidation?.warnings,
                    []
                )
            }
        }
    }

    func testInvalidProfileReturnsTypedCode() async throws {
        let request = makeRequest(
            profile: makeProfile(age: 0)
        )
        let application = try makeTestApplication()

        try await assertError(
            application: application,
            request: request,
            expectedCode: "INVALID_USER_PROFILE",
            expectedDetailCode: "INVALID_AGE"
        )
    }

    func testFutureMedicationRecordReturnsTypedCode() async throws {
        let request = makeRequest(
            records: [
                makeRecord(
                    recordedAt: now.addingTimeInterval(1)
                ),
            ]
        )
        let application = try makeTestApplication()

        try await assertError(
            application: application,
            request: request,
            expectedCode: "FUTURE_MEDICATION_RECORD",
            expectedDetailCode: "FUTURE_MEDICATION_RECORD"
        )
    }

    func testInvalidBodyMetricsReturnsTypedCode() async throws {
        let request = makeRequest(
            profile: makeProfile(
                metrics: makeMetrics(heartRate: 0)
            )
        )
        let application = try makeTestApplication()

        try await assertError(
            application: application,
            request: request,
            expectedCode: "INVALID_BODY_METRICS",
            expectedDetailCode: "BODY_METRICS_NON_POSITIVE"
        )
    }

    func testDataQualityWarningIsReturnedStructurally()
        async throws {
        let request = makeRequest(
            profile: makeProfile(
                metrics: makeMetrics(
                    measuredAt: now.addingTimeInterval(
                        -(31 * 24 * 60 * 60)
                    )
                )
            )
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let output = try self.decode(
                    MedicineAssessmentResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(
                    output.healthContextValidation?.status,
                    "valid_with_warnings"
                )
                XCTAssertTrue(
                    output.healthContextValidation?.warnings
                        .map(\.code)
                        .contains("STALE_BODY_METRICS") == true
                )
                XCTAssertEqual(output.assessment?.level, .yellow)
                XCTAssertEqual(output.actionCard.riskLevel, .yellow)
                XCTAssertTrue(
                    output.assessment?.reasons.map(\.code).contains(
                        .bodyMetricsStale
                    ) == true
                )
            }
        }
    }

    func testUnsupportedProfileSchemaReturnsTypedCode()
        async throws {
        let request = makeRequest(
            profile: makeProfile(schemaVersion: 99)
        )
        let application = try makeTestApplication()

        try await assertError(
            application: application,
            request: request,
            expectedCode: "UNSUPPORTED_PROFILE_SCHEMA",
            expectedDetailCode: "UNSUPPORTED_PROFILE_SCHEMA"
        )
    }

    func testUnsupportedAPIVersionReturnsTypedCode()
        async throws {
        let request = makeRequest(apiVersion: "v999")
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(
                    error.code,
                    "UNSUPPORTED_API_VERSION"
                )
                XCTAssertEqual(error.requestID, request.requestID)
                XCTAssertEqual(
                    error.details?.first?.field,
                    "apiVersion"
                )
            }
        }
    }

    func testMalformedJSONReturnsStableCode() async throws {
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: #"{"userProfile":"#)
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "MALFORMED_REQUEST")
                XCTAssertEqual(
                    error.requestID,
                    self.fallbackRequestID
                )
            }
        }
    }

    func testPrivateHealthValuesAreNotReturnedInErrors()
        async throws {
        let privateValue = "private-allergy-value-47"
        let request = makeRequest(
            profile: makeProfile(
                allergies: [privateValue],
                createdAt: now,
                updatedAt: now.addingTimeInterval(-60)
            )
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(
                    response.status,
                    .unprocessableContent
                )
                let bytes = Array(response.body.readableBytesView)
                let body = String(decoding: bytes, as: UTF8.self)
                XCTAssertFalse(body.contains(privateValue))
                XCTAssertFalse(body.contains("server/"))
                XCTAssertFalse(body.contains("Sources/"))
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "INVALID_USER_PROFILE")
            }
        }
    }

    func testLegacyValidRequestRemainsDecodableWithWarning()
        async throws {
        let application = try makeTestApplication()
        let body = ByteBuffer(
            string:
                """
                {
                  "input": {
                    "recognizedTexts": ["Acetaminophen"],
                    "capturedAt": "2025-07-23T23:59:00Z",
                    "languageCode": "en",
                    "rawConfidence": 0.98
                  },
                  "userProfile": {
                    "id": "00000000-0000-0000-0000-000000000011",
                    "age": 72,
                    "allergies": [],
                    "diagnosedConditions": [],
                    "currentMedicineIngredientIDs": [],
                    "bodyMetrics": {
                      "systolicBloodPressure": 120,
                      "diastolicBloodPressure": 80,
                      "heartRate": 70,
                      "measuredAt": "2025-07-23T23:55:00Z"
                    },
                    "updatedAt": "2025-07-23T23:55:00Z"
                  },
                  "recentRecords": [],
                  "requestID": "00000000-0000-0000-0000-000000000012",
                  "apiVersion": "v1"
                }
                """
        )

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: body
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let output = try self.decode(
                    MedicineAssessmentResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(output.resolution.status, .resolved)
                XCTAssertTrue(
                    output.healthContextValidation?.warnings
                        .map(\.code)
                        .contains(
                            "BODY_METRICS_SOURCE_MISSING"
                        ) == true
                )
                XCTAssertEqual(output.actionCard.riskLevel, .yellow)
            }
        }
    }

    private func assertError<Application: ApplicationProtocol>(
        application: Application,
        request: MedicineAssessmentRequestDTO,
        expectedCode: String,
        expectedDetailCode: String
    ) async throws {
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(
                    response.status,
                    .unprocessableContent
                )
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, expectedCode)
                XCTAssertEqual(error.requestID, request.requestID)
                XCTAssertTrue(
                    error.details?.map(\.code).contains(
                        expectedDetailCode
                    ) == true
                )
            }
        }
    }

    private func makeTestApplication() throws
        -> some ApplicationProtocol {
        try makeSlowWalkApplication(
            configuration: .init(port: 0),
            dateProvider: FixedDateProvider(fixedDate: now),
            uuidProvider: FixedUUIDProvider(
                fixedUUID: fallbackRequestID
            )
        )
    }

    private func makeRequest(
        profile: UserHealthProfile? = nil,
        records: [MedicationRecord] = [],
        apiVersion: String = SlowWalkAPI.version
    ) -> MedicineAssessmentRequestDTO {
        MedicineAssessmentRequestDTO(
            input: MedicineRecognitionInput(
                recognizedTexts: ["Acetaminophen"],
                capturedAt: now.addingTimeInterval(-60),
                languageCode: "en",
                rawConfidence: 0.98
            ),
            userProfile: profile ?? makeProfile(),
            recentRecords: records,
            requestID: requestID,
            apiVersion: apiVersion
        )
    }

    private func makeProfile(
        age: Int = 72,
        allergies: [String] = [],
        metrics: BodyMetrics? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        schemaVersion: Int = 1
    ) -> UserHealthProfile {
        let updateDate = updatedAt ?? now.addingTimeInterval(-300)
        return UserHealthProfile(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 11
                )
            ),
            age: age,
            allergies: allergies,
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: metrics ?? makeMetrics(),
            updatedAt: updateDate,
            createdAt: createdAt ?? updateDate,
            schemaVersion: schemaVersion
        )
    }

    private func makeMetrics(
        heartRate: Int = 70,
        measuredAt: Date? = nil
    ) -> BodyMetrics {
        BodyMetrics(
            systolicBloodPressure: 120,
            diastolicBloodPressure: 80,
            heartRate: heartRate,
            measuredAt: measuredAt
                ?? now.addingTimeInterval(-300),
            source: "demo_data",
            deviceIdentifier: "demo-device"
        )
    }

    private func makeRecord(
        recordedAt: Date
    ) -> MedicationRecord {
        MedicationRecord(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 13
                )
            ),
            medicineID: "demo-acetaminophen",
            activeIngredientIDs: ["acetaminophen"],
            recordedAt: recordedAt,
            eventType: .confirmedIntake,
            source: .demoData
        )
    }

    private var requestID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 12
            )
        )
    }

    private var fallbackRequestID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 99
            )
        )
    }

    private func encode<Value: Encodable>(
        _ value: Value
    ) throws -> ByteBuffer {
        ByteBuffer(
            bytes: try SlowWalkJSONCoding.makeEncoder().encode(
                value
            )
        )
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from buffer: ByteBuffer
    ) throws -> Value {
        let data = Data(buffer.readableBytesView)
        return try SlowWalkJSONCoding.makeDecoder().decode(
            type,
            from: data
        )
    }
}
