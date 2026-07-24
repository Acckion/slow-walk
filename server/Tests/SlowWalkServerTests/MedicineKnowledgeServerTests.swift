import Foundation
import Hummingbird
import HummingbirdTesting
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicineKnowledge
@testable import SlowWalkServer
import XCTest

final class MedicineKnowledgeServerTests:
    XCTestCase,
    @unchecked Sendable
{
    func testSearchSuccessReturnsStructuredSourceEvidence()
        async throws
    {
        let result = try makeKnowledgeResult()
        let application = try makeTestApplication(
            result: .success(result)
        )

        try await executeSearch(
            application: application
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let output = try self.decode(
                MedicineKnowledgeSearchResponseDTO.self,
                from: response.body
            )
            XCTAssertEqual(output.sourceStatus, .authoritative)
            XCTAssertEqual(output.cacheStatus, .miss)
            XCTAssertEqual(output.completeness, 1)
            XCTAssertEqual(output.candidates.count, 1)
            XCTAssertEqual(
                output.sourceVersions,
                ["test-authoritative": "test-v1"]
            )
            XCTAssertEqual(output.apiVersion, SlowWalkAPI.version)
        }
    }

    func testSearchMedicineNotFoundUsesStableCode()
        async throws
    {
        let application = try makeTestApplication(
            result: .failure(.medicineNotFound)
        )

        try await assertSearchError(
            application: application,
            status: .notFound,
            code: "MEDICINE_NOT_FOUND"
        )
    }

    func testSearchTimeoutUsesStableCode() async throws {
        let application = try makeTestApplication(
            result: .failure(
                .knowledgeSourceTimeout(
                    sourceIdentifier: "private-source"
                )
            )
        )

        try await assertSearchError(
            application: application,
            status: .gatewayTimeout,
            code: "KNOWLEDGE_SOURCE_TIMEOUT"
        )
    }

    func testSearchConflictPreservesWarningAndStatus()
        async throws
    {
        let result = try makeKnowledgeResult(
            sourceStatus: .conflicting,
            warning: MedicineKnowledgeWarning(
                code: .sourceConflict,
                message:
                    "Demo sources conflict and require confirmation.",
                sourceIdentifiers: [
                    "test-authoritative",
                    "test-secondary",
                ]
            ),
            requiresConfirmation: true
        )
        let application = try makeTestApplication(
            result: .success(result)
        )

        try await executeSearch(
            application: application
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let output = try self.decode(
                MedicineKnowledgeSearchResponseDTO.self,
                from: response.body
            )
            XCTAssertEqual(output.sourceStatus, .conflicting)
            XCTAssertEqual(
                output.warnings.first?.code,
                .sourceConflict
            )
            XCTAssertTrue(
                output.candidates.first?
                    .requiresConfirmation == true
            )
        }
    }

    func testSearchOfflineCacheIsExplicit()
        async throws
    {
        let result = try makeKnowledgeResult(
            sourceStatus: .staleOffline,
            cacheStatus: .staleOffline,
            warning: MedicineKnowledgeWarning(
                code: .offlineCacheUsed,
                message:
                    "Stale demo cache is in offline use."
            ),
            requiresConfirmation: true,
            isOffline: true
        )
        let application = try makeTestApplication(
            result: .success(result)
        )

        try await executeSearch(
            application: application
        ) { response in
            let output = try self.decode(
                MedicineKnowledgeSearchResponseDTO.self,
                from: response.body
            )
            XCTAssertEqual(output.sourceStatus, .staleOffline)
            XCTAssertEqual(output.cacheStatus, .staleOffline)
            XCTAssertTrue(output.isOffline)
        }
    }

    func testSearchRejectsMalformedNormalizedQuery()
        async throws
    {
        let application = try makeTestApplication(
            result: .success(try makeKnowledgeResult())
        )
        let request = MedicineKnowledgeSearchRequestDTO(
            normalizedQuery: " Acetaminophen ",
            requestID: requestID,
            apiVersion: SlowWalkAPI.version
        )

        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/search",
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
                XCTAssertEqual(error.code, "MALFORMED_REQUEST")
                XCTAssertEqual(
                    error.details?.first?.field,
                    "normalizedQuery"
                )
            }
        }
    }

    func testSearchRejectsUnsupportedAPIVersion()
        async throws
    {
        let application = try makeTestApplication(
            result: .success(try makeKnowledgeResult())
        )

        try await executeSearch(
            application: application,
            apiVersion: "v999"
        ) { response in
            XCTAssertEqual(response.status, .badRequest)
            let error = try self.decode(
                APIErrorDTO.self,
                from: response.body
            )
            XCTAssertEqual(error.code, "MALFORMED_REQUEST")
            XCTAssertEqual(error.requestID, self.requestID)
        }
    }

    func testErrorResponseDoesNotLeakInternalDetails()
        async throws
    {
        let application = try makeTestApplication(
            result: .failure(
                .invalidSourceResponse(
                    sourceIdentifier:
                        "https://secret.invalid/key"
                )
            )
        )

        try await executeSearch(
            application: application
        ) { response in
            XCTAssertEqual(response.status, .badGateway)
            let text = String(
                decoding: response.body.readableBytesView,
                as: UTF8.self
            )
            XCTAssertFalse(text.contains("secret.invalid"))
            XCTAssertFalse(text.contains("/__w/"))
            XCTAssertFalse(text.contains("MedicineKnowledgeServerTests"))
            let error = try self.decode(
                APIErrorDTO.self,
                from: response.body
            )
            XCTAssertEqual(
                error.code,
                "INVALID_SOURCE_RESPONSE"
            )
        }
    }

    func testAssessOnlineKnowledgeSucceeds()
        async throws
    {
        let application = try makeTestApplication(
            result: .success(try makeKnowledgeResult())
        )

        try await executeAssessment(
            application: application
        ) { response in
            XCTAssertEqual(response.status, .ok)
            let output = try self.decode(
                MedicineAssessmentResponseDTO.self,
                from: response.body
            )
            XCTAssertEqual(output.resolution.status, .resolved)
            XCTAssertEqual(
                output.medicineKnowledge?.sourceStatus,
                .authoritative
            )
            XCTAssertEqual(output.assessment?.level, .green)
        }
    }

    func testAssessOfflineKnowledgeCannotBeGreen()
        async throws
    {
        let result = try makeKnowledgeResult(
            sourceStatus: .staleOffline,
            cacheStatus: .staleOffline,
            warning: MedicineKnowledgeWarning(
                code: .offlineCacheUsed,
                message:
                    "Stale demo cache is in offline use."
            ),
            requiresConfirmation: true,
            isOffline: true
        )
        let application = try makeTestApplication(
            result: .success(result)
        )

        try await executeAssessment(
            application: application
        ) { response in
            let output = try self.decode(
                MedicineAssessmentResponseDTO.self,
                from: response.body
            )
            let level = try XCTUnwrap(
                output.assessment?.level
            )
            XCTAssertGreaterThanOrEqual(
                level,
                .yellow
            )
            XCTAssertEqual(
                output.actionCard.riskLevel,
                .yellow
            )
            XCTAssertTrue(output.actionCard.mustConfirmMedicine)
            XCTAssertEqual(output.cacheStatus, .expired)
        }
    }

    func testAssessInsufficientSourceRequiresConfirmation()
        async throws
    {
        let result = try makeKnowledgeResult(
            sourceStatus: .partial,
            warning: MedicineKnowledgeWarning(
                code: .authoritativeSourceMissing,
                message:
                    "No authoritative demo source is available."
            ),
            requiresConfirmation: true
        )
        let application = try makeTestApplication(
            result: .success(result)
        )

        try await executeAssessment(
            application: application
        ) { response in
            let output = try self.decode(
                MedicineAssessmentResponseDTO.self,
                from: response.body
            )
            XCTAssertEqual(output.assessment?.level, .yellow)
            XCTAssertTrue(output.actionCard.mustConfirmMedicine)
            XCTAssertTrue(
                output.actionCard.recommendedActions.contains(
                    .reviewMedicineSources
                )
            )
        }
    }

    func testAssessRedRiskOverridesKnowledgeInstructions()
        async throws
    {
        let application = try makeTestApplication(
            result: .success(try makeKnowledgeResult())
        )

        try await executeAssessment(
            application: application,
            allergies: ["acetaminophen"]
        ) { response in
            let output = try self.decode(
                MedicineAssessmentResponseDTO.self,
                from: response.body
            )
            XCTAssertEqual(output.assessment?.level, .red)
            XCTAssertEqual(output.actionCard.riskLevel, .red)
            XCTAssertFalse(
                output.actionCard.recommendedActions.contains(
                    .followVerifiedSourceInformation
                )
            )
        }
    }

    func testAssessTimeoutReturnsTypedErrorInsteadOfGreen()
        async throws
    {
        let application = try makeTestApplication(
            result: .failure(
                .knowledgeSourceTimeout(
                    sourceIdentifier: "private-source"
                )
            )
        )

        try await executeAssessment(
            application: application
        ) { response in
            XCTAssertEqual(response.status, .gatewayTimeout)
            let error = try self.decode(
                APIErrorDTO.self,
                from: response.body
            )
            XCTAssertEqual(
                error.code,
                "KNOWLEDGE_SOURCE_TIMEOUT"
            )
        }
    }

    private func makeTestApplication(
        result:
            Result<
                MedicineKnowledgeSearchResult,
                MedicineKnowledgeError
            >
    ) throws -> some ApplicationProtocol {
        try makeSlowWalkApplication(
            configuration: .init(port: 0),
            dateProvider: FixedClock(
                fixedDate: knowledgeServerDate
            ),
            uuidProvider: FixedUUIDProvider(
                fixedUUID: fallbackRequestID
            ),
            medicineKnowledgeSearcher:
                ServerStubKnowledgeSearcher(result: result)
        )
    }

    private func executeSearch<
        Application: ApplicationProtocol
    >(
        application: Application,
        apiVersion: String = SlowWalkAPI.version,
        verify:
            @escaping @Sendable (TestResponse) throws -> Void
    ) async throws {
        let request = MedicineKnowledgeSearchRequestDTO(
            normalizedQuery: "acetaminophen",
            requestID: requestID,
            apiVersion: apiVersion
        )
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/search",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                try verify(response)
            }
        }
    }

    private func assertSearchError<
        Application: ApplicationProtocol
    >(
        application: Application,
        status: HTTPResponse.Status,
        code: String
    ) async throws {
        try await executeSearch(
            application: application
        ) { response in
            XCTAssertEqual(response.status, status)
            let error = try self.decode(
                APIErrorDTO.self,
                from: response.body
            )
            XCTAssertEqual(error.code, code)
            XCTAssertEqual(error.requestID, self.requestID)
            XCTAssertNil(error.details)
        }
    }

    private func executeAssessment<
        Application: ApplicationProtocol
    >(
        application: Application,
        allergies: [String] = [],
        verify:
            @escaping @Sendable (TestResponse) throws -> Void
    ) async throws {
        let request = MedicineAssessmentRequestDTO(
            input: MedicineRecognitionInput(
                recognizedTexts: ["Acetaminophen"],
                capturedAt:
                    knowledgeServerDate
                        .addingTimeInterval(-60),
                languageCode: "en",
                rawConfidence: 0.98
            ),
            userProfile: makeProfile(
                allergies: allergies
            ),
            recentRecords: [],
            requestID: requestID,
            apiVersion: SlowWalkAPI.version
        )
        try await application.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/medicine/assess",
                method: .post,
                headers: [.contentType: "application/json"],
                body: try self.encode(request)
            ) { response in
                try verify(response)
            }
        }
    }

    private func makeKnowledgeResult(
        sourceStatus: MedicineKnowledgeSourceStatus =
            .authoritative,
        cacheStatus: MedicineKnowledgeCacheStatus =
            .miss,
        warning: MedicineKnowledgeWarning? = nil,
        requiresConfirmation: Bool = false,
        isOffline: Bool = false
    ) throws -> MedicineKnowledgeSearchResult {
        let base = try XCTUnwrap(
            BundledDemoMedicineCatalogLoader()
                .loadCatalog().medicines.first {
                    $0.canonicalName == "Acetaminophen"
                }
        )
        let medicine = Medicine(
            id: base.id,
            canonicalName: base.canonicalName,
            aliases: base.aliases,
            activeIngredientIDs:
                base.activeIngredientIDs,
            medicineCategory:
                base.medicineCategory,
            sourceReferences:
                base.sourceReferences,
            dosageTextFromSource: nil,
            contraindicationTags:
                base.contraindicationTags,
            warnings: base.warnings,
            dataVersion: "test-v1"
        )
        let warnings = warning.map { [$0] } ?? []
        let candidate = MedicineKnowledgeCandidate(
            medicine: medicine,
            completeness:
                requiresConfirmation ? 0.5 : 1,
            validationStatus:
                requiresConfirmation
                ? .warning
                : .valid,
            sourceIdentifiers: ["test-authoritative"],
            conflicts:
                sourceStatus == .conflicting
                ? [
                    MedicineSourceConflict(
                        medicineIdentifier: medicine.id,
                        field: "activeIngredientIDs",
                        preferredSourceIdentifier:
                            "test-authoritative",
                        conflictingSourceIdentifier:
                            "test-secondary",
                        preferredValue: "acetaminophen",
                        conflictingValue:
                            "conflicting-demo-ingredient"
                    ),
                ]
                : [],
            warnings: warnings,
            requiresConfirmation:
                requiresConfirmation
        )
        return MedicineKnowledgeSearchResult(
            normalizedQuery: "acetaminophen",
            candidates: [candidate],
            sourceStatus: sourceStatus,
            cacheStatus: cacheStatus,
            completeness: candidate.completeness,
            sourceReferences:
                medicine.sourceReferences,
            warnings: warnings,
            sourceVersions: [
                "test-authoritative": "test-v1",
            ],
            generatedAt: knowledgeServerDate,
            isOffline: isOffline
        )
    }

    private func makeProfile(
        allergies: [String]
    ) -> UserHealthProfile {
        UserHealthProfile(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 61
                )
            ),
            age: 72,
            allergies: allergies,
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: BodyMetrics(
                systolicBloodPressure: 120,
                diastolicBloodPressure: 80,
                heartRate: 70,
                measuredAt:
                    knowledgeServerDate
                        .addingTimeInterval(-300),
                source: "demo_data"
            ),
            updatedAt:
                knowledgeServerDate
                    .addingTimeInterval(-300)
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
        try SlowWalkJSONCoding.makeDecoder().decode(
            type,
            from: Data(buffer.readableBytesView)
        )
    }

    private var requestID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 62
            )
        )
    }

    private var fallbackRequestID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 63
            )
        )
    }
}

private struct ServerStubKnowledgeSearcher:
    MedicineKnowledgeSearching,
    Sendable
{
    let result:
        Result<
            MedicineKnowledgeSearchResult,
            MedicineKnowledgeError
        >

    func search(
        query: MedicineKnowledgeQuery
    ) async throws -> MedicineKnowledgeSearchResult {
        try result.get()
    }
}

private let knowledgeServerDate = Date(
    timeIntervalSince1970: 1_753_315_200
)
