import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
import XCTest

final class MedicineAssessmentCoordinatorTests:
    XCTestCase
{
    func testSuccessBuildsCanonicalRequestAndResult()
        async throws
    {
        let requestID = clientTestUUID(40)
        let response = makeMedicineResponse(
            requestID: requestID
        )
        let requester = CapturingMedicineRequester(
            response: response
        )
        let coordinator = try makeCoordinator(
            requester: requester
        )

        let state = await coordinator.assess(
            imageInput: makeOCRImageInput(),
            userProfile: makeClientProfile(),
            recentRecords: [],
            requestID: requestID
        )

        guard case let .result(presentation) = state
        else {
            return XCTFail("Expected medicine result.")
        }
        XCTAssertEqual(presentation.response, response)
        XCTAssertEqual(
            presentation.risk.attention,
            .reviewRequired
        )
        let captured = await requester.request
        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.requestID, requestID)
        XCTAssertEqual(
            request.input.recognizedTexts,
            ["Demo Medicine"]
        )
        XCTAssertEqual(
            request.userProfile,
            makeClientProfile()
        )
    }

    func testAmbiguousResponseRequiresConfirmation()
        async throws
    {
        let response = makeMedicineResponse(
            status: .ambiguous,
            requiresConfirmation: true
        )
        let coordinator = try makeCoordinator(
            requester:
                MockMedicineAssessmentRequester(
                    behavior:
                        .ambiguousMedicine(response)
                )
        )

        let state = await run(coordinator)

        guard case let
            .requiresMedicineConfirmation(requirement) =
                state
        else {
            return XCTFail(
                "Expected confirmation state."
            )
        }
        XCTAssertEqual(
            requirement.reason,
            .ambiguousMedicine
        )
        XCTAssertEqual(requirement.response, response)
    }

    func testIncompleteHealthProfileMapsCanonicalCode()
        async throws
    {
        let requestID = clientTestUUID(41)
        let coordinator = try makeCoordinator(
            requester:
                MockMedicineAssessmentRequester(
                    behavior:
                        .incompleteHealthProfile(
                            requestID: requestID
                        )
                )
        )

        let state = await run(
            coordinator,
            requestID: requestID
        )

        guard case let .failed(failure) = state else {
            return XCTFail("Expected failure state.")
        }
        XCTAssertEqual(
            failure.apiErrorCode,
            .invalidUserProfile
        )
        XCTAssertEqual(failure.requestID, requestID)
        XCTAssertFalse(failure.isRecoverable)
    }

    func testKnowledgeWarningRemainsInResult()
        async throws
    {
        let response = makeMedicineResponse(
            knowledgeWarning: true
        )
        let coordinator = try makeCoordinator(
            requester:
                MockMedicineAssessmentRequester(
                    behavior:
                        .knowledgeSourceWarning(
                            response
                        )
                )
        )

        let state = await run(coordinator)

        guard case let .result(presentation) = state
        else {
            return XCTFail("Expected medicine result.")
        }
        XCTAssertTrue(
            presentation.response.actionCard.warnings
                .contains(
                    "Knowledge source requires review."
                )
        )
        XCTAssertEqual(
            presentation.response.assessment?
                .reasons.first?.code,
            .knowledgeSourceWarning
        )
    }

    func testRedResultHasExplicitImmediateAttention()
        async throws
    {
        let response = makeMedicineResponse(
            riskLevel: .red
        )
        let coordinator = try makeCoordinator(
            requester:
                MockMedicineAssessmentRequester(
                    behavior: .redRisk(response)
                )
        )

        let state = await run(coordinator)

        guard case let .result(presentation) = state
        else {
            return XCTFail("Expected medicine result.")
        }
        XCTAssertEqual(presentation.risk.level, .red)
        XCTAssertEqual(
            presentation.risk.attention,
            .immediateAttention
        )
        XCTAssertTrue(
            presentation.risk
                .requiresImmediateAttention
        )
    }

    func testRequesterCancellationIsNotNetworkFailure()
        async throws
    {
        let coordinator = try makeCoordinator(
            requester:
                MockMedicineAssessmentRequester(
                    behavior: .cancellation
                )
        )

        let state = await run(coordinator)

        XCTAssertEqual(state, .cancelled)
    }

    func testExplicitCancellationStopsOwnedOperation()
        async throws
    {
        let coordinator = try makeCoordinator(
            requester: CancellableMedicineRequester()
        )
        let task = Task {
            await coordinator.assess(
                imageInput: makeOCRImageInput(),
                userProfile: makeClientProfile(),
                recentRecords: [],
                requestID: clientTestUUID(40)
            )
        }

        var reachedAssessing = false
        for _ in 0 ..< 1_000 {
            if case .assessing =
                await coordinator.state
            {
                reachedAssessing = true
                break
            }
            await Task.yield()
        }
        XCTAssertTrue(reachedAssessing)

        await coordinator.cancelCurrentAssessment()
        let result = await task.value
        let finalState = await coordinator.state

        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(finalState, .cancelled)
    }

    func testTimeoutMapsToRecoverableTimeout()
        async throws
    {
        let coordinator = try makeCoordinator(
            requester:
                MockMedicineAssessmentRequester(
                    behavior: .timeout
                )
        )

        let state = await run(coordinator)

        guard case let .failed(failure) = state else {
            return XCTFail("Expected timeout failure.")
        }
        XCTAssertEqual(failure.kind, .timeout)
        XCTAssertEqual(
            failure.endpoint,
            .medicineAssess
        )
        XCTAssertTrue(failure.isRecoverable)
    }

    func testMalformedResponseIsNotRetriedOrCancelled()
        async throws
    {
        let coordinator = try makeCoordinator(
            requester:
                MockMedicineAssessmentRequester(
                    behavior: .malformedResponse
                )
        )

        let state = await run(coordinator)

        guard case let .failed(failure) = state else {
            return XCTFail("Expected malformed failure.")
        }
        XCTAssertEqual(
            failure.kind,
            .malformedResponse
        )
        XCTAssertFalse(failure.isRecoverable)
    }

    func testMismatchedResponseIsRejectedBeforePresentation()
        async throws
    {
        let coordinator = try makeCoordinator(
            requester: CapturingMedicineRequester(
                response: makeMedicineResponse(
                    requestID: clientTestUUID(99)
                )
            )
        )

        let state = await run(coordinator)

        guard case let .failed(failure) = state else {
            return XCTFail("Expected malformed response failure.")
        }
        XCTAssertEqual(failure.kind, .malformedResponse)
        XCTAssertFalse(failure.isRecoverable)
    }

    func testLocalAmbiguousCandidateCanBeConfirmed()
        async throws
    {
        let requester = LocalMedicineAssessmentRequester()
        let coordinator = MedicineAssessmentCoordinator(
            recognizer: MockMedicineTextRecognizer(
                behavior: .observations([
                    makeObservation(text: "Cold Relief"),
                ])
            ),
            mapper: try makeRecognitionMapper(),
            requester: requester,
            confirmer: requester,
            clock: FixedClientClock(date: clientTestDate),
            apiVersion: SlowWalkAPI.version
        )
        let first = await run(
            coordinator,
            requestID: clientTestUUID(70)
        )
        guard case let .requiresMedicineConfirmation(requirement) = first,
              let candidate = requirement.response?
                .resolution.candidates.first
        else {
            return XCTFail("Expected an offered ambiguous candidate.")
        }

        let confirmed = await coordinator.confirmMedicine(
            candidateID: candidate.medicine.id
        )

        guard case let .result(presentation) = confirmed else {
            return XCTFail("Expected confirmed pipeline result.")
        }
        XCTAssertEqual(
            presentation.response.resolution.selectedMedicine?.id,
            candidate.medicine.id
        )
        XCTAssertEqual(
            presentation.response.resolution.evidence.recognizedTexts,
            ["Cold Relief"]
        )
    }

    func testStateStreamPublishesAssessmentProgress() async throws {
        let coordinator = try makeCoordinator(
            requester: CapturingMedicineRequester(
                response: makeMedicineResponse()
            )
        )
        let stream = await coordinator.stateUpdates()
        let collector = Task {
            var values: [MedicineAssessmentViewState] = []
            for await value in stream {
                values.append(value)
                if case .result = value { break }
            }
            return values
        }

        _ = await run(coordinator)
        let values = await collector.value

        XCTAssertTrue(values.contains(.idle))
        XCTAssertTrue(values.contains { if case .recognizing = $0 { true } else { false } })
        XCTAssertTrue(values.contains { if case .assessing = $0 { true } else { false } })
        XCTAssertTrue(values.contains { if case .result = $0 { true } else { false } })
    }

    func testEmptyOCRSkipsNetworkAndRequiresConfirmation()
        async throws
    {
        let recognizer = MockMedicineTextRecognizer(
            behavior: .observations([
                makeObservation(text: " "),
            ])
        )
        let coordinator = MedicineAssessmentCoordinator(
            recognizer: recognizer,
            mapper: try makeRecognitionMapper(),
            requester: CancellableMedicineRequester(),
            clock: FixedClientClock(
                date: clientTestDate
            ),
            apiVersion: SlowWalkAPI.version
        )

        let state = await run(coordinator)

        guard case let
            .requiresMedicineConfirmation(requirement) =
                state
        else {
            return XCTFail(
                "Expected confirmation state."
            )
        }
        XCTAssertEqual(
            requirement.reason,
            .noRecognizedText
        )
        XCTAssertNil(requirement.response)
    }

    func testCanonicalAPIErrorMapperDoesNotCopyMessage()
    {
        let requestID = clientTestUUID(42)
        let error = ClientAPIError(
            error: APIErrorDTO(
                code: .locationDataStale,
                message: "private coordinates",
                requestID: requestID,
                details: [
                    APIErrorDetailDTO(
                        field: "recentSamples",
                        code: "PRIVATE",
                        message: "private trajectory"
                    ),
                ]
            )
        )

        let failure = ClientFailureMapper.map(error)

        XCTAssertEqual(
            failure.apiErrorCode,
            .locationDataStale
        )
        XCTAssertEqual(failure.requestID, requestID)
        XCTAssertFalse(
            String(reflecting: failure)
                .contains("private")
        )
    }

    private func makeCoordinator(
        requester:
            any MedicineAssessmentRequesting
    ) throws -> MedicineAssessmentCoordinator {
        MedicineAssessmentCoordinator(
            recognizer: MockMedicineTextRecognizer(
                behavior: .observations([
                    makeObservation(),
                ])
            ),
            mapper: try makeRecognitionMapper(),
            requester: requester,
            clock: FixedClientClock(
                date: clientTestDate
            ),
            apiVersion: SlowWalkAPI.version
        )
    }

    private func run(
        _ coordinator:
            MedicineAssessmentCoordinator,
        requestID: UUID = clientTestUUID(40)
    ) async -> MedicineAssessmentViewState {
        await coordinator.assess(
            imageInput: makeOCRImageInput(),
            userProfile: makeClientProfile(),
            recentRecords: [],
            requestID: requestID
        )
    }
}
