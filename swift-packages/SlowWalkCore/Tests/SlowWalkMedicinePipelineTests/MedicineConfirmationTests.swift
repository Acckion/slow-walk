import SlowWalkDomain
import SlowWalkMedicinePipeline
import XCTest

final class MedicineConfirmationTests: XCTestCase {
    func testAmbiguousCandidateConfirmationReusesOriginalEvidence()
        async throws
    {
        let pipeline = makePipeline()
        let original = try await pipeline.assess(
            input: makeRecognitionInput(["Cold Relief"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(original.resolution.status, .ambiguous)
        let context = try XCTUnwrap(original.confirmationContext)
        let candidate = try XCTUnwrap(context.candidates.first)

        let confirmed = try await pipeline.assessConfirmedCandidate(
            candidateID: candidate.medicine.id,
            context: context,
            userProfile: makePipelineProfile(),
            recentRecords: []
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
        XCTAssertEqual(confirmed.scanEvent.recognizedText, "Cold Relief")
        XCTAssertNotNil(confirmed.assessment)
        XCTAssertFalse(confirmed.resolution.requiresUserConfirmation)
    }

    func testCandidateThatWasNotOfferedIsRejected() async throws {
        let pipeline = makePipeline()
        let original = try await pipeline.assess(
            input: makeRecognitionInput(["Cold Relief"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )
        let context = try XCTUnwrap(original.confirmationContext)

        do {
            _ = try await pipeline.assessConfirmedCandidate(
                candidateID: "not-offered",
                context: context,
                userProfile: makePipelineProfile(),
                recentRecords: []
            )
            XCTFail("Expected an unoffered candidate to be rejected.")
        } catch let error as MedicineConfirmationError {
            XCTAssertEqual(error, .candidateNotOffered)
        }
    }

    func testResolvedResultDoesNotExposeConfirmationContext()
        async throws
    {
        let result = try await makePipeline().assess(
            input: makeRecognitionInput(["Acetaminophen"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(result.resolution.status, .resolved)
        XCTAssertNil(result.confirmationContext)
    }
}
