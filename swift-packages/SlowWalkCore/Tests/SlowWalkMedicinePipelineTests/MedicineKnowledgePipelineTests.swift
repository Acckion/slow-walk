import Foundation
import SlowWalkDomain
import SlowWalkMedicineKnowledge
import SlowWalkMedicinePipeline
import XCTest

final class MedicineKnowledgePipelineTests:
    XCTestCase,
    @unchecked Sendable
{
    func testKnowledgeCacheHitStillReevaluatesCurrentHealth()
        async throws
    {
        let searcher = StaticKnowledgeSearcher(
            result: .success(
                makeKnowledgeResult(cacheStatus: .hit)
            )
        )
        let pipeline = makePipeline(
            knowledgeSearcher: searcher
        )
        let input = makeRecognitionInput(["Acetaminophen"])

        let first = try await pipeline.assess(
            input: input,
            userProfile: makePipelineProfile(),
            recentRecords: []
        )
        let second = try await pipeline.assess(
            input: input,
            userProfile: makePipelineProfile(
                allergies: ["acetaminophen"]
            ),
            recentRecords: []
        )

        XCTAssertTrue(first.cacheHit)
        XCTAssertEqual(first.assessment?.level, .green)
        XCTAssertEqual(second.assessment?.level, .red)
        XCTAssertEqual(second.actionCard.riskLevel, .red)
        let searchCount = await searcher.searchCount()
        XCTAssertEqual(searchCount, 2)
    }

    func testSourceConflictCannotProduceGreenActionCard()
        async throws
    {
        let knowledge = makeKnowledgeResult(
            sourceStatus: .conflicting,
            warnings: [
                MedicineKnowledgeWarning(
                    code: .sourceConflict,
                    message:
                        "Demo sources conflict and require confirmation.",
                    sourceIdentifiers: [
                        "authoritative",
                        "secondary",
                    ]
                )
            ],
            candidateRequiresConfirmation: true
        )
        let pipeline = makePipeline(
            knowledgeSearcher: StaticKnowledgeSearcher(
                result: .success(knowledge)
            )
        )

        let result = try await pipeline.assess(
            input: makeRecognitionInput(["Acetaminophen"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(result.assessment?.level, .yellow)
        XCTAssertEqual(result.actionCard.riskLevel, .yellow)
        XCTAssertTrue(
            result.resolution.requiresUserConfirmation
        )
        XCTAssertTrue(
            result.actionCard.mustConfirmMedicine
        )
        XCTAssertTrue(
            result.assessment?.reasons.contains {
                $0.code == .knowledgeSourceWarning
            } == true
        )
        XCTAssertFalse(
            result.actionCard.recommendedActions.contains(
                .followVerifiedSourceInformation
            )
        )
    }

    func testOfflineKnowledgeIsExplicitAndConservative()
        async throws
    {
        let knowledge = makeKnowledgeResult(
            sourceStatus: .staleOffline,
            cacheStatus: .staleOffline,
            warnings: [
                MedicineKnowledgeWarning(
                    code: .offlineCacheUsed,
                    message:
                        "Stale demo cache is in offline use."
                )
            ],
            candidateRequiresConfirmation: true,
            isOffline: true
        )
        let pipeline = makePipeline(
            knowledgeSearcher: StaticKnowledgeSearcher(
                result: .success(knowledge)
            )
        )

        let result = try await pipeline.assess(
            input: makeRecognitionInput(["Acetaminophen"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(result.cacheStatus, .expired)
        XCTAssertFalse(result.cacheHit)
        XCTAssertEqual(
            result.assessment?.evidenceCompleteness,
            .insufficient
        )
        XCTAssertGreaterThanOrEqual(
            result.actionCard.riskLevel,
            .yellow
        )
        XCTAssertTrue(
            result.actionCard.warnings.contains(
                "Stale demo cache is in offline use."
            )
        )
        XCTAssertTrue(result.resolution.requiresUserConfirmation)
        XCTAssertNil(result.confirmationContext)
    }

    func testCandidateConfirmationDoesNotClearKnowledgeReview()
        async throws
    {
        let catalog = try loadDemoCatalog()
        let medicines = catalog.medicines.filter {
            $0.aliases.contains("Cold Relief")
        }
        let candidates = medicines.map {
            MedicineKnowledgeCandidate(
                medicine: $0,
                completeness: 0.5,
                validationStatus: .warning,
                sourceIdentifiers: ["authoritative"],
                conflicts: [],
                warnings: [],
                requiresConfirmation: true
            )
        }
        let knowledge = MedicineKnowledgeSearchResult(
            normalizedQuery: "cold relief",
            candidates: candidates,
            sourceStatus: .partial,
            cacheStatus: .miss,
            completeness: 0.5,
            sourceReferences: medicines.flatMap(\.sourceReferences),
            warnings: [],
            sourceVersions: ["authoritative": "demo-v1"],
            generatedAt: pipelineTestDate,
            isOffline: false
        )
        let pipeline = makePipeline(
            knowledgeSearcher: StaticKnowledgeSearcher(
                result: .success(knowledge)
            )
        )
        let initial = try await pipeline.assess(
            input: makeRecognitionInput(["Cold Relief"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )
        let context = try XCTUnwrap(initial.confirmationContext)
        let candidate = try XCTUnwrap(context.candidates.first)

        let confirmed = try await pipeline.assessConfirmedCandidate(
            candidateID: candidate.medicine.id,
            context: context,
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(confirmed.resolution.status, .resolved)
        XCTAssertTrue(confirmed.resolution.requiresUserConfirmation)
        XCTAssertTrue(confirmed.actionCard.mustConfirmMedicine)
        XCTAssertNil(confirmed.confirmationContext)
    }

    func testRedRiskOverridesOtherwiseNormalKnowledge()
        async throws
    {
        let pipeline = makePipeline(
            knowledgeSearcher: StaticKnowledgeSearcher(
                result: .success(makeKnowledgeResult())
            )
        )

        let result = try await pipeline.assess(
            input: makeRecognitionInput(["Acetaminophen"]),
            userProfile: makePipelineProfile(
                allergies: ["acetaminophen"]
            ),
            recentRecords: []
        )

        XCTAssertEqual(result.assessment?.level, .red)
        XCTAssertEqual(result.actionCard.riskLevel, .red)
        XCTAssertFalse(
            result.actionCard.recommendedActions.contains(
                .followVerifiedSourceInformation
            )
        )
        XCTAssertTrue(
            result.actionCard.primaryInstruction.hasPrefix(
                "Do not take"
            )
        )
    }

    func testMissingSourceDosageStaysNil() async throws {
        let knowledge = makeKnowledgeResult()
        let pipeline = makePipeline(
            knowledgeSearcher: StaticKnowledgeSearcher(
                result: .success(knowledge)
            )
        )

        let result = try await pipeline.resolve(
            input: makeRecognitionInput(["Acetaminophen"])
        )

        XCTAssertEqual(result.resolution.status, .resolved)
        XCTAssertNil(
            result.resolution.selectedMedicine?
                .dosageTextFromSource
        )
    }

    func testNetworkFailureCannotReturnFalseGreen()
        async throws
    {
        let pipeline = makePipeline(
            knowledgeSearcher: StaticKnowledgeSearcher(
                result: .failure(
                    .knowledgeSourceUnavailable(
                        sourceIdentifier: nil
                    )
                )
            )
        )

        do {
            _ = try await pipeline.assess(
                input: makeRecognitionInput([
                    "Acetaminophen"
                ]),
                userProfile: makePipelineProfile(),
                recentRecords: []
            )
            XCTFail("Expected knowledge source failure.")
        } catch let error as MedicineKnowledgeError {
            XCTAssertEqual(
                error,
                .knowledgeSourceUnavailable(
                    sourceIdentifier: nil
                )
            )
        }
    }

    private func makeKnowledgeResult(
        sourceStatus: MedicineKnowledgeSourceStatus =
            .authoritative,
        cacheStatus: MedicineKnowledgeCacheStatus =
            .miss,
        warnings: [MedicineKnowledgeWarning] = [],
        candidateRequiresConfirmation: Bool = false,
        isOffline: Bool = false
    ) -> MedicineKnowledgeSearchResult {
        let catalog = try! loadDemoCatalog()
        let medicine = catalog.medicines.first {
            $0.canonicalName == "Acetaminophen"
        }!
        let candidate = MedicineKnowledgeCandidate(
            medicine: medicine,
            completeness:
                candidateRequiresConfirmation ? 0.5 : 1,
            validationStatus:
                candidateRequiresConfirmation
                ? .warning
                : .valid,
            sourceIdentifiers: ["authoritative"],
            conflicts:
                sourceStatus == .conflicting
                ? [
                    MedicineSourceConflict(
                        medicineIdentifier: medicine.id,
                        field: "activeIngredientIDs",
                        preferredSourceIdentifier:
                            "authoritative",
                        conflictingSourceIdentifier:
                            "secondary",
                        preferredValue: "acetaminophen",
                        conflictingValue:
                            "conflicting-demo-ingredient"
                    )
                ]
                : [],
            warnings: warnings,
            requiresConfirmation:
                candidateRequiresConfirmation
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
                "authoritative": "demo-v1"
            ],
            generatedAt: pipelineTestDate,
            isOffline: isOffline
        )
    }
}

private actor StaticKnowledgeSearcher:
    MedicineKnowledgeSearching
{
    private let result:
        Result<
            MedicineKnowledgeSearchResult,
            MedicineKnowledgeError
        >
    private var count = 0

    init(
        result:
            Result<
                MedicineKnowledgeSearchResult,
                MedicineKnowledgeError
            >
    ) {
        self.result = result
    }

    func search(
        query: MedicineKnowledgeQuery
    ) async throws -> MedicineKnowledgeSearchResult {
        count += 1
        return try result.get()
    }

    func searchCount() -> Int {
        count
    }
}
