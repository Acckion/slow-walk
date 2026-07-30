import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
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

    private func makeRequest(
        texts: [String],
        requestID: UUID
    ) -> MedicineAssessmentRequestDTO {
        MedicineAssessmentRequestDTO(
            input: MedicineRecognitionInput(
                recognizedTexts: texts,
                capturedAt: clientTestDate,
                languageCode: "en",
                rawConfidence: 0.99
            ),
            userProfile: makeClientProfile(),
            recentRecords: [],
            requestID: requestID,
            apiVersion: SlowWalkAPI.version
        )
    }
}
