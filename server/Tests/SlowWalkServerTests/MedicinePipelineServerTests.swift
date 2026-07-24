import Foundation
import Hummingbird
import HummingbirdTesting
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
@testable import SlowWalkServer
import XCTest

final class MedicinePipelineServerTests: XCTestCase, @unchecked Sendable {
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testResolveReturnsResolvedMedicineAndMetadata() async throws {
        let request = try makeResolutionRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(
                    response.headers[.contentType],
                    "application/json; charset=utf-8"
                )

                let output = try self.decode(
                    MedicineResolutionResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(output.requestID, request.requestID)
                XCTAssertEqual(output.resolution.status, .resolved)
                XCTAssertEqual(
                    output.resolution.selectedMedicine?.canonicalName,
                    "Acetaminophen"
                )
                XCTAssertFalse(output.resolution.requiresUserConfirmation)
                XCTAssertEqual(output.cacheStatus, .miss)
                XCTAssertFalse(output.cacheHit)
                XCTAssertEqual(
                    output.sourceDataVersion,
                    "slowwalk-demo-catalog-v1"
                )
                XCTAssertEqual(output.generatedAt, self.now)
                XCTAssertEqual(output.apiVersion, SlowWalkAPI.version)
            }
        }
    }

    func testResolveReportsCacheHitOnRepeatedQuery() async throws {
        let request = try makeResolutionRequest(
            texts: ["Paracetamol"],
            confidence: 0.98
        )
        let body = try encode(request)
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: body
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let output = try self.decode(
                    MedicineResolutionResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(output.cacheStatus, .miss)
                XCTAssertFalse(output.cacheHit)
            }

            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: body
            ) { response in
                XCTAssertEqual(response.status, .ok)
                let output = try self.decode(
                    MedicineResolutionResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(output.cacheStatus, .hit)
                XCTAssertTrue(output.cacheHit)
                XCTAssertEqual(output.resolution.status, .resolved)
            }
        }
    }

    func testResolveMapsAmbiguousToConflict() async throws {
        let request = try makeResolutionRequest(
            texts: ["Cold Relief"],
            confidence: 0.98
        )
        let application = try makeTestApplication()

        try await assertResolutionError(
            application: application,
            request: request,
            expectedStatus: .conflict,
            expectedCode: "medicine_ambiguous"
        )
    }

    func testResolveMapsNotFoundToNotFound() async throws {
        let request = try makeResolutionRequest(
            texts: ["Unknown Remedy"],
            confidence: 0.98
        )
        let application = try makeTestApplication()

        try await assertResolutionError(
            application: application,
            request: request,
            expectedStatus: .notFound,
            expectedCode: "medicine_not_found"
        )
    }

    func testResolveMapsRecognitionFailureToUnprocessableContent() async throws {
        let request = try makeResolutionRequest(
            texts: ["###", "OTC"],
            confidence: 0.98
        )
        let application = try makeTestApplication()

        try await assertResolutionError(
            application: application,
            request: request,
            expectedStatus: .unprocessableContent,
            expectedCode: "medicine_recognition_failed"
        )
    }

    func testResolveMapsInsufficientEvidenceToUnprocessableContent() async throws {
        let request = try makeResolutionRequest(
            texts: ["Ibuprofen"],
            confidence: 0.40
        )
        let application = try makeTestApplication()

        try await assertResolutionError(
            application: application,
            request: request,
            expectedStatus: .unprocessableContent,
            expectedCode: "medicine_insufficient_evidence"
        )
    }

    func testResolveMalformedJSONUsesTypedFallbackError() async throws {
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: #"{"input":"#)
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "invalid_json")
                XCTAssertEqual(error.requestID, try self.fallbackRequestID())
                XCTAssertNil(error.details)
            }
        }
    }

    func testResolveMissingFieldUsesStructuredDecodingError() async throws {
        let request = try makeResolutionRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(
                    ResolutionRequestWithoutAPIVersion(request)
                )
            ) { response in
                XCTAssertEqual(response.status, .unprocessableContent)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "validation_error")
                XCTAssertEqual(error.requestID, try self.fallbackRequestID())
                XCTAssertEqual(error.details?.first?.field, "apiVersion")
                XCTAssertEqual(
                    error.details?.first?.code,
                    "missing_required_field"
                )
            }
        }
    }

    func testResolveRejectsUnsupportedAPIVersionWithRequestID() async throws {
        let request = try makeResolutionRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98,
            apiVersion: "v999"
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "unsupported_api_version")
                XCTAssertEqual(error.requestID, request.requestID)
                XCTAssertEqual(error.details?.first?.field, "apiVersion")
            }
        }
    }

    func testResolveRejectsOutOfRangeConfidence() async throws {
        let request = try makeResolutionRequest(
            texts: ["Acetaminophen"],
            confidence: 1.01
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .unprocessableContent)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "validation_error")
                XCTAssertEqual(error.requestID, request.requestID)
                XCTAssertTrue(
                    error.details?.contains {
                        $0.field == "input.rawConfidence"
                            && $0.code == "out_of_range"
                    } == true
                )
            }
        }
    }

    func testResolveRequiresJSONContentType() async throws {
        let request = try makeResolutionRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "unsupported_media_type")
                XCTAssertEqual(error.requestID, try self.fallbackRequestID())
            }
        }
    }

    func testAssessResolvedReturnsAssessmentAndActionCard() async throws {
        let request = try makeAssessmentRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98
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
                XCTAssertEqual(output.requestID, request.requestID)
                XCTAssertEqual(output.resolution.status, .resolved)
                XCTAssertNotNil(output.assessment)
                XCTAssertEqual(output.actionCard.title, "Acetaminophen")
                XCTAssertFalse(output.actionCard.mustConfirmMedicine)
                XCTAssertEqual(output.actionCard.generatedAt, self.now)
                XCTAssertEqual(output.generatedAt, self.now)
                XCTAssertEqual(output.apiVersion, SlowWalkAPI.version)
            }
        }
    }

    func testAssessAllergyRiskReturnsRedDoNotTakeActionCard() async throws {
        let request = try makeAssessmentRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98,
            allergies: ["acetaminophen"]
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
                XCTAssertEqual(output.resolution.status, .resolved)
                XCTAssertEqual(output.assessment?.level, .red)
                XCTAssertEqual(output.actionCard.riskLevel, .red)
                XCTAssertTrue(
                    output.actionCard.primaryInstruction.hasPrefix(
                        "Do not take"
                    )
                )
                XCTAssertTrue(
                    output.actionCard.recommendedActions.contains(
                        .doNotTakeUntilMedicineConfirmed
                    )
                )
                XCTAssertFalse(
                    output.actionCard.recommendedActions.contains(
                        .followVerifiedSourceInformation
                    )
                )
            }
        }
    }

    func testAssessCacheHitStillReturnsFreshAssessment() async throws {
        let request = try makeAssessmentRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98
        )
        let body = try encode(request)
        let application = try makeTestApplication()

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
                XCTAssertEqual(output.cacheStatus, .miss)
                XCTAssertFalse(output.cacheHit)
                XCTAssertNotNil(output.assessment)
            }

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
                XCTAssertEqual(output.cacheStatus, .hit)
                XCTAssertTrue(output.cacheHit)
                XCTAssertNotNil(output.assessment)
                XCTAssertEqual(output.assessment?.level, .green)
            }
        }
    }

    func testAssessAmbiguousReturnsSafeActionCard() async throws {
        try await assertSafeAssessment(
            texts: ["Cold Relief"],
            confidence: 0.98,
            expectedStatus: .ambiguous
        )
    }

    func testAssessNotFoundReturnsSafeActionCard() async throws {
        try await assertSafeAssessment(
            texts: ["Unknown Remedy"],
            confidence: 0.98,
            expectedStatus: .notFound
        )
    }

    func testAssessEmptyRecognitionReturnsSafeActionCard() async throws {
        try await assertSafeAssessment(
            texts: [],
            confidence: 0.98,
            expectedStatus: .recognitionFailed
        )
    }

    func testAssessBlankRecognitionReturnsSafeActionCard() async throws {
        try await assertSafeAssessment(
            texts: ["", "   "],
            confidence: 0.98,
            expectedStatus: .recognitionFailed
        )
    }

    func testAssessInsufficientEvidenceReturnsSafeActionCard() async throws {
        try await assertSafeAssessment(
            texts: ["Ibuprofen"],
            confidence: 0.40,
            expectedStatus: .insufficientEvidence
        )
    }

    func testAssessRejectsInvalidUserAge() async throws {
        let request = try makeAssessmentRequest(
            texts: ["Acetaminophen"],
            confidence: 0.98,
            age: 0
        )
        let application = try makeTestApplication()

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, .unprocessableContent)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, "INVALID_USER_PROFILE")
                XCTAssertEqual(error.requestID, request.requestID)
                XCTAssertTrue(
                    error.details?.contains {
                        $0.field == "userProfile.age"
                            && $0.code == "INVALID_AGE"
                    } == true
                )
            }
        }
    }

    private func assertResolutionError<Application: ApplicationProtocol>(
        application: Application,
        request: MedicineResolutionRequestDTO,
        expectedStatus: HTTPResponse.Status,
        expectedCode: String
    ) async throws {
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/resolve",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                XCTAssertEqual(response.status, expectedStatus)
                let error = try self.decode(
                    APIErrorDTO.self,
                    from: response.body
                )
                XCTAssertEqual(error.code, expectedCode)
                XCTAssertEqual(error.requestID, request.requestID)
                XCTAssertNil(error.details)
            }
        }
    }

    private func assertSafeAssessment(
        texts: [String],
        confidence: Double?,
        expectedStatus: MedicineResolutionStatus
    ) async throws {
        let request = try makeAssessmentRequest(
            texts: texts,
            confidence: confidence
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
                XCTAssertEqual(output.requestID, request.requestID)
                XCTAssertEqual(output.resolution.status, expectedStatus)
                XCTAssertNil(output.assessment)
                XCTAssertTrue(output.actionCard.mustConfirmMedicine)
                XCTAssertEqual(output.actionCard.riskLevel, .yellow)
                XCTAssertTrue(
                    output.actionCard.recommendedActions.contains(
                        .doNotTakeUntilMedicineConfirmed
                    )
                )
                XCTAssertTrue(
                    output.actionCard.recommendedActions.contains(
                        .retakeMedicinePhoto
                    )
                )
                XCTAssertEqual(output.actionCard.generatedAt, self.now)
            }
        }
    }

    private func makeTestApplication() throws -> some ApplicationProtocol {
        try makeSlowWalkApplication(
            configuration: .init(port: 0),
            dateProvider: FixedDateProvider(fixedDate: now),
            uuidProvider: FixedUUIDProvider(
                fixedUUID: try fallbackRequestID()
            )
        )
    }

    private func makeResolutionRequest(
        texts: [String],
        confidence: Double?,
        apiVersion: String = SlowWalkAPI.version
    ) throws -> MedicineResolutionRequestDTO {
        MedicineResolutionRequestDTO(
            input: recognitionInput(
                texts: texts,
                confidence: confidence
            ),
            requestID: try requestID(),
            apiVersion: apiVersion
        )
    }

    private func makeAssessmentRequest(
        texts: [String],
        confidence: Double?,
        age: Int = 72,
        allergies: [String] = []
    ) throws -> MedicineAssessmentRequestDTO {
        MedicineAssessmentRequestDTO(
            input: recognitionInput(
                texts: texts,
                confidence: confidence
            ),
            userProfile: try userProfile(
                age: age,
                allergies: allergies
            ),
            recentRecords: [],
            requestID: try requestID(),
            apiVersion: SlowWalkAPI.version
        )
    }

    private func recognitionInput(
        texts: [String],
        confidence: Double?
    ) -> MedicineRecognitionInput {
        MedicineRecognitionInput(
            recognizedTexts: texts,
            capturedAt: now.addingTimeInterval(-60),
            languageCode: "en",
            rawConfidence: confidence
        )
    }

    private func userProfile(
        age: Int,
        allergies: [String]
    ) throws -> UserHealthProfile {
        UserHealthProfile(
            id: try makeUUID(
                "00000000-0000-0000-0000-000000000011"
            ),
            age: age,
            allergies: allergies,
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: BodyMetrics(
                systolicBloodPressure: 120,
                diastolicBloodPressure: 80,
                heartRate: 70,
                measuredAt: now.addingTimeInterval(-300),
                source: "demo_data"
            ),
            updatedAt: now.addingTimeInterval(-300)
        )
    }

    private func requestID() throws -> UUID {
        try makeUUID("00000000-0000-0000-0000-000000000012")
    }

    private func fallbackRequestID() throws -> UUID {
        try makeUUID("00000000-0000-0000-0000-000000000099")
    }

    private func makeUUID(
        _ value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> UUID {
        try XCTUnwrap(
            UUID(uuidString: value),
            "Invalid UUID test fixture.",
            file: file,
            line: line
        )
    }

    private func encode<Value: Encodable>(
        _ value: Value
    ) throws -> ByteBuffer {
        ByteBuffer(bytes: try SlowWalkJSONCoding.makeEncoder().encode(value))
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from buffer: ByteBuffer
    ) throws -> Value {
        let data = Data(buffer.readableBytesView)
        return try SlowWalkJSONCoding.makeDecoder().decode(type, from: data)
    }
}

private struct ResolutionRequestWithoutAPIVersion: Encodable {
    let input: MedicineRecognitionInput
    let requestID: UUID

    init(_ request: MedicineResolutionRequestDTO) {
        input = request.input
        requestID = request.requestID
    }
}
