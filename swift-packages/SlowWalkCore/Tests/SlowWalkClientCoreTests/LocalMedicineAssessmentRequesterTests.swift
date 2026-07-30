import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicinePipeline
import XCTest

final class LocalMedicineAssessmentRequesterTests: XCTestCase {
    func testAssessmentRunsPipelineLocally() async throws {
        let requester = LocalMedicineAssessmentRequester(
            clock: FixedClientClock(date: clientTestDate)
        )
        let request = makeRequest(
            texts: ["Acetaminophen"],
            requestID: clientTestUUID(60)
        )

        let response = try await requester.assess(request: request)

        XCTAssertEqual(response.requestID, request.requestID)
        XCTAssertEqual(response.apiVersion, request.apiVersion)
        XCTAssertEqual(response.resolution.status, .resolved)
        XCTAssertEqual(
            response.resolution.selectedMedicine?.id,
            "demo-acetaminophen"
        )
        XCTAssertFalse(response.sourceDataVersion.isEmpty)
        XCTAssertEqual(response.generatedAt, clientTestDate)
        XCTAssertNoThrow(
            try MedicineAssessmentResponseValidator().validate(
                response,
                for: request
            )
        )
    }

    func testAmbiguousConfirmationAcceptsOnlyOfferedCandidate()
        async throws
    {
        let requester = LocalMedicineAssessmentRequester()
        let request = makeRequest(
            texts: ["Cold Relief"],
            requestID: clientTestUUID(61)
        )
        let ambiguous = try await requester.assess(request: request)
        XCTAssertEqual(ambiguous.resolution.status, .ambiguous)
        let candidate = try XCTUnwrap(
            ambiguous.resolution.candidates.first
        )

        let confirmed = try await requester.confirmMedicine(
            command: MedicineCandidateConfirmationCommand(
                originalRequestID: request.requestID,
                candidateID: candidate.medicine.id
            )
        )

        XCTAssertEqual(confirmed.resolution.status, .resolved)
        XCTAssertEqual(
            confirmed.resolution.selectedMedicine?.id,
            candidate.medicine.id
        )
        XCTAssertEqual(
            confirmed.resolution.evidence.recognizedTexts,
            ["Cold Relief"]
        )
    }

    func testForgedCandidateIsRejectedWithoutConsumingContext()
        async throws
    {
        let requester = LocalMedicineAssessmentRequester()
        let request = makeRequest(
            texts: ["Cold Relief"],
            requestID: clientTestUUID(62)
        )
        let ambiguous = try await requester.assess(request: request)

        do {
            _ = try await requester.confirmMedicine(
                command: MedicineCandidateConfirmationCommand(
                    originalRequestID: request.requestID,
                    candidateID: "forged-candidate"
                )
            )
            XCTFail("Expected forged candidate rejection.")
        } catch let error as LocalMedicineConfirmationError {
            XCTAssertEqual(error, .candidateNotOffered)
        }

        let offered = try XCTUnwrap(
            ambiguous.resolution.candidates.first
        )
        let confirmed = try await requester.confirmMedicine(
            command: MedicineCandidateConfirmationCommand(
                originalRequestID: request.requestID,
                candidateID: offered.medicine.id
            )
        )
        XCTAssertEqual(confirmed.resolution.status, .resolved)
    }

    func testNewAssessmentInvalidatesOldConfirmationContext()
        async throws
    {
        let requester = LocalMedicineAssessmentRequester()
        let oldRequest = makeRequest(
            texts: ["Cold Relief"],
            requestID: clientTestUUID(63)
        )
        let ambiguous = try await requester.assess(request: oldRequest)
        let candidate = try XCTUnwrap(
            ambiguous.resolution.candidates.first
        )

        _ = try await requester.assess(
            request: makeRequest(
                texts: ["Acetaminophen"],
                requestID: clientTestUUID(64)
            )
        )

        do {
            _ = try await requester.confirmMedicine(
                command: MedicineCandidateConfirmationCommand(
                    originalRequestID: oldRequest.requestID,
                    candidateID: candidate.medicine.id
                )
            )
            XCTFail("Expected stale confirmation rejection.")
        } catch let error as LocalMedicineConfirmationError {
            XCTAssertEqual(error, .noPendingAssessment)
        }
    }

    func testOlderConcurrentAssessmentCannotReplaceNewConfirmationContext()
        async throws
    {
        let cache = OutOfOrderMedicineCache()
        let requester = LocalMedicineAssessmentRequester(
            pipeline: MedicinePipeline(
                cache: cache,
                dateProvider: FixedClientClock(date: clientTestDate)
            )
        )
        let firstRequest = makeRequest(
            texts: ["Cold Relief"],
            requestID: clientTestUUID(74)
        )
        let secondRequest = makeRequest(
            texts: ["Cold Relief"],
            requestID: clientTestUUID(75)
        )

        let firstTask = Task {
            try await requester.assess(request: firstRequest)
        }
        await cache.waitUntilFirstLookupIsSuspended()
        let second = try await requester.assess(request: secondRequest)
        await cache.releaseFirstLookup()
        _ = try await firstTask.value

        let candidate = try XCTUnwrap(second.resolution.candidates.first)
        let confirmed = try await requester.confirmMedicine(
            command: MedicineCandidateConfirmationCommand(
                originalRequestID: secondRequest.requestID,
                candidateID: candidate.medicine.id
            )
        )

        XCTAssertEqual(confirmed.requestID, secondRequest.requestID)
        XCTAssertEqual(confirmed.resolution.status, .resolved)
    }

    func testUnsupportedProfileSchemaUsesCanonicalAPIError() async {
        let requester = LocalMedicineAssessmentRequester(
            clock: FixedClientClock(date: clientTestDate)
        )
        let profile = UserHealthProfileDTO(
            id: clientTestUUID(76),
            age: 70,
            allergies: [],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: nil,
            createdAt: clientTestDate,
            updatedAt: clientTestDate,
            schemaVersion: 999
        )

        do {
            _ = try await requester.assess(
                request: makeRequest(
                    texts: ["Acetaminophen"],
                    requestID: clientTestUUID(77),
                    userProfile: profile
                )
            )
            XCTFail("Expected unsupported profile schema rejection.")
        } catch let error as ClientAPIError {
            XCTAssertEqual(error.error.code, .unsupportedProfileSchema)
            XCTAssertEqual(error.error.requestID, clientTestUUID(77))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidMedicationRecordEnumUsesCanonicalAPIError() async {
        let requester = LocalMedicineAssessmentRequester(
            clock: FixedClientClock(date: clientTestDate)
        )
        let record = MedicationRecordDTO(
            id: clientTestUUID(78),
            medicineID: "demo-acetaminophen",
            activeIngredientIDs: ["acetaminophen"],
            recordedAt: clientTestDate,
            eventType: "unsupported-event",
            source: "manual"
        )

        do {
            _ = try await requester.assess(
                request: makeRequest(
                    texts: ["Acetaminophen"],
                    requestID: clientTestUUID(79),
                    recentRecords: [record]
                )
            )
            XCTFail("Expected invalid medication record rejection.")
        } catch let error as ClientAPIError {
            XCTAssertEqual(error.error.code, .invalidMedicationRecord)
            XCTAssertEqual(error.error.requestID, clientTestUUID(79))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResponseValidatorRejectsRequestIDMismatch() {
        let request = makeRequest(
            texts: ["Demo Medicine"],
            requestID: clientTestUUID(65)
        )
        let response = makeMedicineResponse(
            requestID: clientTestUUID(66)
        )

        XCTAssertThrowsError(
            try MedicineAssessmentResponseValidator().validate(
                response,
                for: request
            )
        ) { error in
            XCTAssertEqual(
                error as? MedicineAssessmentResponseValidationError,
                .requestIDMismatch
            )
        }
    }

    func testResponseValidatorRejectsConfirmationMismatch() {
        let requestID = clientTestUUID(67)
        let request = makeRequest(
            texts: ["Demo Medicine"],
            requestID: requestID
        )
        let response = makeMedicineResponse(
            requestID: requestID,
            requiresConfirmation: true,
            cardRequiresConfirmation: false
        )

        XCTAssertThrowsError(
            try MedicineAssessmentResponseValidator().validate(
                response,
                for: request
            )
        ) { error in
            XCTAssertEqual(
                error as? MedicineAssessmentResponseValidationError,
                .confirmationMismatch
            )
        }
    }

    func testResponseValidatorRejectsResolvedResponseWithoutAssessment() {
        let requestID = clientTestUUID(68)
        let request = makeRequest(
            texts: ["Demo Medicine"],
            requestID: requestID
        )
        let response = makeMedicineResponse(
            requestID: requestID,
            includeAssessment: false
        )

        XCTAssertThrowsError(
            try MedicineAssessmentResponseValidator().validate(
                response,
                for: request
            )
        ) { error in
            XCTAssertEqual(
                error as? MedicineAssessmentResponseValidationError,
                .assessmentMismatch
            )
        }
    }

    func testResponseValidatorAcceptsConservativeRiskElevation() {
        let requestID = clientTestUUID(80)
        let request = makeRequest(
            texts: ["Demo Medicine"],
            requestID: requestID
        )
        let response = makeMedicineResponse(
            requestID: requestID,
            riskLevel: .yellow,
            assessmentRiskLevel: .green
        )

        XCTAssertNoThrow(
            try MedicineAssessmentResponseValidator().validate(
                response,
                for: request
            )
        )
    }

    func testResponseValidatorRejectsSelectedMedicinePayloadMismatch() {
        let requestID = clientTestUUID(81)
        let request = makeRequest(
            texts: ["Demo Medicine"],
            requestID: requestID
        )
        let response = makeMedicineResponse(
            requestID: requestID,
            selectedMedicineName: "Altered Medicine"
        )

        XCTAssertThrowsError(
            try MedicineAssessmentResponseValidator().validate(
                response,
                for: request
            )
        ) { error in
            XCTAssertEqual(
                error as? MedicineAssessmentResponseValidationError,
                .invalidResolution
            )
        }
    }

    private func makeRequest(
        texts: [String],
        requestID: UUID,
        userProfile: UserHealthProfileDTO = makeClientProfile(),
        recentRecords: [MedicationRecordDTO] = []
    ) -> MedicineAssessmentRequestDTO {
        MedicineAssessmentRequestDTO(
            input: MedicineRecognitionInput(
                recognizedTexts: texts,
                capturedAt: clientTestDate,
                languageCode: "en",
                rawConfidence: 0.99
            ),
            userProfile: userProfile,
            recentRecords: recentRecords,
            requestID: requestID,
            apiVersion: SlowWalkAPI.version
        )
    }
}

private actor OutOfOrderMedicineCache: MedicineCache {
    private var lookupCount = 0
    private var firstLookupContinuation: CheckedContinuation<Void, Never>?
    private var firstLookupWaiters = [CheckedContinuation<Void, Never>]()

    func cachedMedicine(id: String) async throws -> Medicine? {
        nil
    }

    func store(_ medicine: Medicine) async throws {}

    func removeMedicine(id: String) async throws {}

    func removeAll() async throws {}

    func cachedResolution(
        normalizedQuery: String,
        sourceDataVersion: String,
        now: Date
    ) async throws -> MedicineResolutionCacheLookup {
        lookupCount += 1
        if lookupCount == 1 {
            let waiters = firstLookupWaiters
            firstLookupWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
            await withCheckedContinuation { continuation in
                firstLookupContinuation = continuation
            }
        }
        return MedicineResolutionCacheLookup(status: .miss)
    }

    func storeResolution(
        _ resolution: MedicineResolution,
        normalizedQuery: String,
        sourceDataVersion: String,
        now: Date
    ) async throws {}

    func waitUntilFirstLookupIsSuspended() async {
        guard lookupCount == 0 else { return }
        await withCheckedContinuation { continuation in
            firstLookupWaiters.append(continuation)
        }
    }

    func releaseFirstLookup() {
        firstLookupContinuation?.resume()
        firstLookupContinuation = nil
    }
}
