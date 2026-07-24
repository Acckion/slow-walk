import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicinePipeline
import XCTest

final class MedicinePipelineTests: XCTestCase {
    func testResolveMissThenHit() async throws {
        let cache = InMemoryMedicineCache()
        let pipeline = makePipeline(cache: cache)
        let input = makeRecognitionInput(["Acetaminophen"])

        let first = try await pipeline.resolve(input: input)
        let second = try await pipeline.resolve(input: input)

        XCTAssertEqual(first.cacheStatus, .miss)
        XCTAssertFalse(first.cacheHit)
        XCTAssertEqual(second.cacheStatus, .hit)
        XCTAssertTrue(second.cacheHit)
        XCTAssertEqual(second.resolution.status, .resolved)
    }

    func testCacheHitRevalidatesCurrentLowConfidence() async throws {
        let cache = InMemoryMedicineCache()
        let pipeline = makePipeline(cache: cache)

        let first = try await pipeline.resolve(
            input: makeRecognitionInput(
                ["Ibuprofen"],
                confidence: 0.98
            )
        )
        let second = try await pipeline.resolve(
            input: makeRecognitionInput(
                ["Ibuprofen"],
                confidence: 0.2
            )
        )

        XCTAssertEqual(first.resolution.status, .resolved)
        XCTAssertEqual(second.cacheStatus, .hit)
        XCTAssertTrue(second.cacheHit)
        XCTAssertEqual(
            second.resolution.status,
            .insufficientEvidence
        )
        XCTAssertNil(second.resolution.selectedMedicine)
    }

    func testCacheKeyIncludesEveryOCRQueryVariant() async throws {
        let cache = InMemoryMedicineCache()
        let pipeline = makePipeline(cache: cache)

        let first = try await pipeline.resolve(
            input: makeRecognitionInput([
                "Acetaminophen",
                "tablets",
            ])
        )
        let second = try await pipeline.resolve(
            input: makeRecognitionInput([
                "Acetaminophen",
                "Ibuprofen",
            ])
        )

        XCTAssertEqual(first.resolution.status, .resolved)
        XCTAssertEqual(first.cacheStatus, .miss)
        XCTAssertEqual(second.cacheStatus, .miss)
        XCTAssertFalse(second.cacheHit)
        XCTAssertEqual(second.resolution.status, .ambiguous)
        XCTAssertNil(second.resolution.selectedMedicine)
    }

    func testCacheHitStillRunsFreshRiskAssessment() async throws {
        let cache = InMemoryMedicineCache()
        let pipeline = makePipeline(cache: cache)
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

        XCTAssertEqual(first.assessment?.level, .green)
        XCTAssertEqual(second.cacheStatus, .hit)
        XCTAssertEqual(second.assessment?.level, .red)
        XCTAssertEqual(second.actionCard.riskLevel, .red)
    }

    func testCacheHitRebuildsContextFromCurrentHistory() async throws {
        let cache = InMemoryMedicineCache()
        let pipeline = makePipeline(cache: cache)
        let input = makeRecognitionInput(["Acetaminophen"])
        let record = MedicationRecord(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 43
                )
            ),
            medicineID: "another-acetaminophen-product",
            activeIngredientIDs: ["acetaminophen"],
            recordedAt: pipelineTestDate.addingTimeInterval(-60),
            eventType: .confirmedIntake,
            source: .demoData
        )

        let first = try await pipeline.assess(
            input: input,
            userProfile: makePipelineProfile(),
            recentRecords: []
        )
        let second = try await pipeline.assess(
            input: input,
            userProfile: makePipelineProfile(),
            recentRecords: [record]
        )

        XCTAssertEqual(first.assessment?.level, .green)
        XCTAssertEqual(second.cacheStatus, .hit)
        XCTAssertEqual(second.assessment?.level, .red)
        XCTAssertTrue(
            second.assessment?.reasons.map(\.code).contains(
                .duplicateActiveIngredient
            ) == true
        )
    }

    func testResolvedAssessmentUsesInjectedDateAndUUID() async throws {
        let pipeline = makePipeline()
        let capturedAt = pipelineTestDate.addingTimeInterval(-30)

        let result = try await pipeline.assess(
            input: makeRecognitionInput(
                ["Metformin"],
                capturedAt: capturedAt
            ),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(result.generatedAt, pipelineTestDate)
        XCTAssertEqual(result.scanEvent.id, pipelineTestUUID)
        XCTAssertEqual(result.scanEvent.scannedAt, capturedAt)
        XCTAssertEqual(
            result.scanEvent.recognitionStatus,
            .recognized
        )
        XCTAssertEqual(
            result.assessment?.assessedAt,
            pipelineTestDate
        )
    }

    func testAmbiguousResolutionSkipsRiskAssessment() async throws {
        let result = try await makePipeline().assess(
            input: makeRecognitionInput(["Cold Relief"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(result.resolution.status, .ambiguous)
        XCTAssertNil(result.assessment)
        XCTAssertTrue(result.actionCard.mustConfirmMedicine)
        XCTAssertEqual(
            result.scanEvent.recognitionStatus,
            .uncertain
        )
        XCTAssertNil(result.scanEvent.candidateMedicineID)
    }

    func testNotFoundResolutionSkipsRiskAssessment() async throws {
        let result = try await makePipeline().assess(
            input: makeRecognitionInput(["Unknown Remedy"]),
            userProfile: makePipelineProfile(),
            recentRecords: []
        )

        XCTAssertEqual(result.resolution.status, .notFound)
        XCTAssertNil(result.assessment)
        XCTAssertEqual(
            result.scanEvent.recognitionStatus,
            .failed
        )
        XCTAssertEqual(result.actionCard.riskLevel, .yellow)
    }

    func testRecognitionFailureIsNotCachedWithEmptyKey() async throws {
        let cache = InMemoryMedicineCache()
        let pipeline = makePipeline(cache: cache)
        let input = makeRecognitionInput(["###", "OTC"])

        let first = try await pipeline.resolve(input: input)
        let second = try await pipeline.resolve(input: input)

        XCTAssertEqual(
            first.resolution.status,
            .recognitionFailed
        )
        XCTAssertEqual(first.cacheStatus, .miss)
        XCTAssertEqual(second.cacheStatus, .miss)
        XCTAssertFalse(second.cacheHit)
    }

    func testResolutionResultIncludesCatalogMetadata() async throws {
        let result = try await makePipeline().resolve(
            input: makeRecognitionInput(["Loratadine"])
        )

        XCTAssertEqual(
            result.sourceDataVersion,
            "slowwalk-demo-catalog-v1"
        )
        XCTAssertEqual(result.generatedAt, pipelineTestDate)
        XCTAssertEqual(
            result.resolution.evidence.sourceDataVersions,
            ["slowwalk-demo-catalog-v1"]
        )
    }

    func testExpiredResolutionIsRecomputed() async throws {
        let cache = InMemoryMedicineCache(
            resolutionPolicy: try MedicineResolutionCachePolicy(
                timeToLive: 60
            )
        )
        let firstPipeline = makePipeline(
            cache: cache,
            date: pipelineTestDate
        )
        let laterPipeline = makePipeline(
            cache: cache,
            date: pipelineTestDate.addingTimeInterval(61)
        )
        let input = makeRecognitionInput(["Famotidine"])

        _ = try await firstPipeline.resolve(input: input)
        let later = try await laterPipeline.resolve(input: input)

        XCTAssertEqual(later.cacheStatus, .expired)
        XCTAssertFalse(later.cacheHit)
        XCTAssertEqual(later.resolution.status, .resolved)
    }
}
