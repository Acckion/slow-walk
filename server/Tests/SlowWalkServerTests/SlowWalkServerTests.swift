import Foundation
import HummingbirdTesting
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
@testable import SlowWalkServer
import XCTest

final class SlowWalkServerTests: XCTestCase, @unchecked Sendable {
    private let now = Date(timeIntervalSince1970: 1_735_689_600)

    func testHealthReturnsContractJSON() async throws {
        let fallbackID = try makeUUID("00000000-0000-0000-0000-000000000099")
        let application = makeTestApplication(fallbackID: fallbackID)

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/health",
                method: .get
            ) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(
                    response.headers[.contentType],
                    "application/json; charset=utf-8"
                )
                let health = try decode(
                    HealthResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(
                    health,
                    HealthResponseDTO(
                        status: "ok",
                        service: "slow-walk-server",
                        apiVersion: "v1"
                    )
                )
            }
        }
    }

    func testRiskAssessmentSuccessUsesCoreEngine() async throws {
        let fallbackID = try makeUUID("00000000-0000-0000-0000-000000000099")
        let request = try makeValidRequest()
        let body = try encode(request)
        let application = makeTestApplication(fallbackID: fallbackID)

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/risk/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: body
            ) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(
                    response.headers[.contentType],
                    "application/json; charset=utf-8"
                )

                let output = try decode(
                    RiskAssessmentResponseDTO.self,
                    from: response.body
                )
                XCTAssertEqual(output.requestID, request.requestID)
                XCTAssertEqual(output.generatedAt, self.now)
                XCTAssertEqual(output.apiVersion, SlowWalkAPI.version)
                XCTAssertEqual(output.assessment.level, .green)
                XCTAssertEqual(output.assessment.assessedAt, self.now)
                XCTAssertEqual(output.assessment.reasons, [])
                XCTAssertEqual(
                    output.assessment.recommendedActions,
                    [.followVerifiedSourceInformation]
                )
                XCTAssertFalse(output.assessment.requiresProfessionalAdvice)
                XCTAssertFalse(output.assessment.requiresFamilyAttention)
                XCTAssertEqual(
                    output.assessment.evidenceCompleteness,
                    .complete
                )
                XCTAssertEqual(
                    output.sourceReferences,
                    request.medicine.sourceReferences
                )
            }
        }
    }

    func testMalformedJSONReturnsTypedError() async throws {
        let fallbackID = try makeUUID("00000000-0000-0000-0000-000000000099")
        let application = makeTestApplication(fallbackID: fallbackID)

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/risk/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: #"{"medicine":"#)
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let error = try decode(APIErrorDTO.self, from: response.body)
                XCTAssertEqual(error.code, "invalid_json")
                XCTAssertEqual(error.requestID, fallbackID)
                XCTAssertNil(error.details)
            }
        }
    }

    func testMissingRequiredFieldReturnsValidationError() async throws {
        let fallbackID = try makeUUID("00000000-0000-0000-0000-000000000099")
        let validRequest = try makeValidRequest()
        let request = RequestWithoutAPIVersion(validRequest)
        let application = makeTestApplication(fallbackID: fallbackID)

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/risk/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try encode(request)
            ) { response in
                XCTAssertEqual(response.status, .unprocessableContent)
                let error = try decode(APIErrorDTO.self, from: response.body)
                XCTAssertEqual(error.code, "validation_error")
                XCTAssertEqual(error.requestID, fallbackID)
                XCTAssertEqual(error.details?.first?.field, "apiVersion")
                XCTAssertEqual(
                    error.details?.first?.code,
                    "missing_required_field"
                )
            }
        }
    }

    func testSemanticValidationReturnsFieldDetails() async throws {
        let fallbackID = try makeUUID("00000000-0000-0000-0000-000000000099")
        let invalidRequest = try makeRequest(age: 0)
        let application = makeTestApplication(fallbackID: fallbackID)

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/risk/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try encode(invalidRequest)
            ) { response in
                XCTAssertEqual(response.status, .unprocessableContent)
                let error = try decode(APIErrorDTO.self, from: response.body)
                XCTAssertEqual(error.code, "validation_error")
                XCTAssertEqual(error.requestID, invalidRequest.requestID)
                XCTAssertTrue(
                    error.details?.contains {
                        $0.field == "userProfile.age"
                            && $0.code == "out_of_range"
                    } == true
                )
            }
        }
    }

    private func makeTestApplication(
        fallbackID: UUID
    ) -> some ApplicationProtocol {
        makeSlowWalkApplication(
            configuration: .init(port: 0),
            dateProvider: FixedDateProvider(fixedDate: now),
            uuidProvider: FixedUUIDProvider(fixedUUID: fallbackID)
        )
    }

    private func makeValidRequest() throws -> RiskAssessmentRequestDTO {
        try makeRequest(age: 72)
    }

    private func makeRequest(age: Int) throws -> RiskAssessmentRequestDTO {
        let source = SourceReference(
            sourceName: "Demo medicines reference",
            documentTitle: "Acetaminophen demo monograph",
            optionalURL: nil,
            retrievedAt: now.addingTimeInterval(-86_400),
            versionOrDate: "2025-01-01"
        )
        let medicine = Medicine(
            id: "medicine-acetaminophen",
            canonicalName: "Acetaminophen",
            aliases: ["Paracetamol"],
            activeIngredientIDs: ["acetaminophen"],
            medicineCategory: .analgesic,
            sourceReferences: [source],
            dosageTextFromSource: nil,
            contraindicationTags: []
        )
        let bodyMetrics = BodyMetrics(
            systolicBloodPressure: 120,
            diastolicBloodPressure: 80,
            heartRate: 70,
            measuredAt: now.addingTimeInterval(-300)
        )
        let userProfile = UserHealthProfile(
            id: try makeUUID("00000000-0000-0000-0000-000000000001"),
            age: age,
            allergies: [],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: bodyMetrics,
            updatedAt: now.addingTimeInterval(-300)
        )
        let scanEvent = MedicineScanEvent(
            id: try makeUUID("00000000-0000-0000-0000-000000000002"),
            recognizedText: "Acetaminophen",
            candidateMedicineID: medicine.id,
            confidence: 0.99,
            scannedAt: now.addingTimeInterval(-60),
            recognitionStatus: .recognized
        )

        return RiskAssessmentRequestDTO(
            medicine: medicine,
            userProfile: userProfile,
            recentRecords: [],
            scanEvent: scanEvent,
            requestID: try makeUUID(
                "00000000-0000-0000-0000-000000000003"
            ),
            apiVersion: SlowWalkAPI.version
        )
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

private struct RequestWithoutAPIVersion: Encodable {
    let medicine: Medicine
    let userProfile: UserHealthProfile
    let recentRecords: [MedicationRecord]
    let scanEvent: MedicineScanEvent
    let requestID: UUID

    init(_ request: RiskAssessmentRequestDTO) {
        medicine = request.medicine
        userProfile = request.userProfile
        recentRecords = request.recentRecords
        scanEvent = request.scanEvent
        requestID = request.requestID
    }
}
