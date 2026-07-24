import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicineKnowledge
import XCTest

final class MedicineKnowledgeServiceTests:
    XCTestCase,
    @unchecked Sendable
{
    func testConsistentSourcesAreMergedAndCorroborated()
        async throws
    {
        let primary = makeSource(
            identifier: primaryID,
            priority: 100,
            authoritative: true,
            response: makeResponse(
                sourceIdentifier: primaryID,
                version: "primary-v1"
            )
        )
        let secondary = makeSource(
            identifier: secondaryID,
            priority: 10,
            authoritative: false,
            response: makeResponse(
                sourceIdentifier: secondaryID,
                version: "secondary-v1"
            )
        )
        let service = try makeService(
            sources: [secondary, primary]
        )

        let result = try await service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        XCTAssertEqual(result.sourceStatus, .corroborated)
        XCTAssertEqual(result.cacheStatus, .miss)
        XCTAssertEqual(result.candidates.count, 1)
        XCTAssertEqual(
            result.candidates[0].sourceIdentifiers,
            [primaryID, secondaryID]
        )
        XCTAssertEqual(
            result.candidates[0].medicine.activeIngredientIDs,
            ["acetaminophen"]
        )
        XCTAssertTrue(
            result.candidates[0].conflicts.isEmpty
        )
        XCTAssertFalse(result.requiresConservativeAction)
    }

    func testLowerPriorityConflictPreservesEvidenceAndPrimaryValue()
        async throws
    {
        let primary = makeSource(
            identifier: primaryID,
            priority: 100,
            authoritative: true,
            response: makeResponse(
                sourceIdentifier: primaryID,
                version: "primary-v1"
            )
        )
        let secondary = makeSource(
            identifier: secondaryID,
            priority: 10,
            authoritative: false,
            response: makeResponse(
                sourceIdentifier: secondaryID,
                version: "secondary-v1",
                activeIngredientIDs: [
                    "conflicting-demo-ingredient",
                ]
            )
        )
        let service = try makeService(
            sources: [secondary, primary]
        )

        let result = try await service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )
        let candidate = try XCTUnwrap(
            result.candidates.first
        )

        XCTAssertEqual(result.sourceStatus, .conflicting)
        XCTAssertEqual(
            candidate.medicine.activeIngredientIDs,
            ["acetaminophen"]
        )
        XCTAssertTrue(
            candidate.conflicts.contains {
                $0.field == "activeIngredientIDs"
                    && $0.preferredSourceIdentifier
                        == primaryID
                    && $0.conflictingSourceIdentifier
                        == secondaryID
            }
        )
        XCTAssertTrue(
            result.warnings.contains {
                $0.code == .sourceConflict
            }
        )
        XCTAssertLessThan(candidate.completeness, 1)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(result.requiresConservativeAction)
    }

    func testSecondaryOnlyResultIsPartialAndHasNoDosage()
        async throws
    {
        let secondary = makeSource(
            identifier: secondaryID,
            priority: 10,
            authoritative: false,
            response: makeResponse(
                sourceIdentifier: secondaryID,
                version: "secondary-v1"
            )
        )
        let service = try makeService(sources: [secondary])

        let result = try await service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )
        let candidate = try XCTUnwrap(
            result.candidates.first
        )

        XCTAssertEqual(result.sourceStatus, .partial)
        XCTAssertNil(
            candidate.medicine.dosageTextFromSource
        )
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(
            candidate.warnings.contains {
                $0.code == .authoritativeSourceMissing
            }
        )
    }

    func testStaleSourceProducesWarningAndPartialStatus()
        async throws
    {
        let staleDate = serviceTestDate
            .addingTimeInterval(-61)
        let source = makeSource(
            identifier: primaryID,
            priority: 100,
            authoritative: true,
            response: makeResponse(
                sourceIdentifier: primaryID,
                version: "primary-v1",
                fetchedAt: staleDate
            )
        )
        let service = try makeService(
            sources: [source],
            maximumSourceAge: 60
        )

        let result = try await service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        XCTAssertEqual(result.sourceStatus, .partial)
        XCTAssertTrue(
            result.warnings.contains {
                $0.code == .sourceStale
            }
        )
        XCTAssertTrue(result.requiresConservativeAction)
    }

    func testUnsupportedVersionIsNotTrustedOrCached()
        async throws
    {
        let source = makeSource(
            identifier: primaryID,
            priority: 100,
            authoritative: true,
            supportedVersion: "primary-v1",
            response: makeResponse(
                sourceIdentifier: primaryID,
                version: "unsupported-v2"
            )
        )
        let cache = InMemoryMedicineKnowledgeCache()
        let service = try makeService(
            sources: [source],
            cache: cache
        )

        await assertThrows(
            .sourceVersionUnsupported(
                sourceIdentifier: primaryID,
                version: "unsupported-v2"
            )
        ) {
            try await service.search(
                query: .init(
                    normalizedQuery: "acetaminophen"
                )
            )
        }
        let lookup = try await cache.lookup(
            normalizedQuery: "acetaminophen",
            now: serviceTestDate
        )
        XCTAssertEqual(lookup.status, .miss)
        XCTAssertNil(lookup.entry)
    }

    func testETagRevalidationUses304CachedResponse()
        async throws
    {
        let clock = MutableKnowledgeClock(
            date: serviceTestDate
        )
        let transport = DemoMockHTTPTransport(
            medicines: [makeDemoMedicine()],
            fetchedAt: serviceTestDate
        )
        let cache = InMemoryMedicineKnowledgeCache(
            policy: try MedicineKnowledgeCachePolicy(
                timeToLive: 1,
                offlineGracePeriod: 60
            )
        )
        let service = try MedicineKnowledgeService(
            sources: [
                try MockAuthoritativeMedicineSource(
                    transport: transport,
                    clock: clock
                ),
                try MockSecondaryMedicineSource(
                    transport: transport,
                    clock: clock
                ),
            ],
            policy: .demo,
            cache: cache,
            clock: clock
        )

        let first = try await service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )
        clock.advance(by: 2)
        let second = try await service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        XCTAssertEqual(first.cacheStatus, .miss)
        XCTAssertEqual(second.cacheStatus, .revalidated)
        XCTAssertEqual(
            second.candidates,
            first.candidates
        )
    }

    func testExpiredCacheFallsBackToExplicitStaleOffline()
        async throws
    {
        let clock = MutableKnowledgeClock(
            date: serviceTestDate
        )
        let cache = InMemoryMedicineKnowledgeCache(
            policy: try MedicineKnowledgeCachePolicy(
                timeToLive: 1,
                offlineGracePeriod: 60
            )
        )
        let successful = makeSource(
            identifier: primaryID,
            priority: 100,
            authoritative: true,
            response: makeResponse(
                sourceIdentifier: primaryID,
                version: "primary-v1"
            )
        )
        let onlineService = try makeService(
            sources: [successful],
            cache: cache,
            clock: clock
        )
        _ = try await onlineService.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        clock.advance(by: 2)
        let unavailable = makeFailingSource(
            identifier: primaryID,
            priority: 100,
            authoritative: true,
            version: "primary-v1",
            error: .knowledgeSourceUnavailable(
                sourceIdentifier: primaryID
            )
        )
        let offlineService = try makeService(
            sources: [unavailable],
            cache: cache,
            clock: clock
        )
        let result = try await offlineService.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        XCTAssertEqual(result.sourceStatus, .staleOffline)
        XCTAssertEqual(result.cacheStatus, .staleOffline)
        XCTAssertTrue(result.isOffline)
        XCTAssertTrue(
            result.warnings.contains {
                $0.code == .offlineCacheUsed
            }
        )
        XCTAssertNil(
            result.candidates.first?
                .medicine.dosageTextFromSource
        )
        XCTAssertTrue(
            result.candidates.first?
                .requiresConfirmation == true
        )
    }

    func testOfflineCacheOutsideGraceIsUnavailable()
        async throws
    {
        let clock = MutableKnowledgeClock(
            date: serviceTestDate
        )
        let cache = InMemoryMedicineKnowledgeCache(
            policy: try MedicineKnowledgeCachePolicy(
                timeToLive: 1,
                offlineGracePeriod: 1
            )
        )
        let onlineService = try makeService(
            sources: [
                makeSource(
                    identifier: primaryID,
                    priority: 100,
                    authoritative: true,
                    response: makeResponse(
                        sourceIdentifier: primaryID,
                        version: "primary-v1"
                    )
                ),
            ],
            cache: cache,
            clock: clock
        )
        _ = try await onlineService.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )
        clock.advance(by: 3)
        let offlineService = try makeService(
            sources: [
                makeFailingSource(
                    identifier: primaryID,
                    priority: 100,
                    authoritative: true,
                    version: "primary-v1",
                    error: .knowledgeSourceUnavailable(
                        sourceIdentifier: primaryID
                    )
                ),
            ],
            cache: cache,
            clock: clock
        )

        await assertThrows(.offlineCacheUnavailable) {
            try await offlineService.search(
                query: .init(
                    normalizedQuery: "acetaminophen"
                )
            )
        }
    }

    func testSourceVersionChangeInvalidatesOldVersion()
        async throws
    {
        let clock = MutableKnowledgeClock(
            date: serviceTestDate
        )
        let cache = InMemoryMedicineKnowledgeCache(
            policy: try MedicineKnowledgeCachePolicy(
                timeToLive: 1,
                offlineGracePeriod: 60
            )
        )
        let v1Service = try makeService(
            sources: [
                makeSource(
                    identifier: primaryID,
                    priority: 100,
                    authoritative: true,
                    supportedVersion: "primary-v1",
                    response: makeResponse(
                        sourceIdentifier: primaryID,
                        version: "primary-v1"
                    )
                ),
            ],
            cache: cache,
            clock: clock
        )
        _ = try await v1Service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        clock.advance(by: 2)
        let v2Service = try makeService(
            sources: [
                makeSource(
                    identifier: primaryID,
                    priority: 100,
                    authoritative: true,
                    supportedVersion: "primary-v2",
                    response: makeResponse(
                        sourceIdentifier: primaryID,
                        version: "primary-v2",
                        fetchedAt: clock.now()
                    )
                ),
            ],
            cache: cache,
            clock: clock
        )
        let result = try await v2Service.search(
            query: .init(
                normalizedQuery: "acetaminophen"
            )
        )

        XCTAssertEqual(
            result.cacheStatus,
            .sourceVersionChanged
        )
        XCTAssertEqual(
            result.sourceVersions[primaryID],
            "primary-v2"
        )
    }

    func testNoConfiguredSourceIsUnavailable()
        async throws
    {
        let service = try makeService(sources: [])

        await assertThrows(
            .knowledgeSourceUnavailable(
                sourceIdentifier: nil
            )
        ) {
            try await service.search(
                query: .init(
                    normalizedQuery: "acetaminophen"
                )
            )
        }
    }

    private func makeService(
        sources: [any MedicineKnowledgeSource],
        cache: any MedicineKnowledgeCaching =
            InMemoryMedicineKnowledgeCache(),
        clock: any Clock =
            FixedClock(fixedDate: serviceTestDate),
        maximumSourceAge: TimeInterval = 3_600
    ) throws -> MedicineKnowledgeService {
        try MedicineKnowledgeService(
            sources: sources,
            policy: SourcePolicy(
                allowedSourceIdentifiers: Set(
                    sources.map(\.identifier)
                ),
                maximumSourceAge: maximumSourceAge,
                minimumCompleteness: 0.5,
                conflictPenalty: 0.25
            ),
            cache: cache,
            clock: clock
        )
    }

    private func makeSource(
        identifier: String,
        priority: Int,
        authoritative: Bool,
        supportedVersion: String? = nil,
        response: MedicineKnowledgeSourceResponse
    ) -> StubMedicineKnowledgeSource {
        StubMedicineKnowledgeSource(
            identifier: identifier,
            displayName: identifier,
            priority: priority,
            isAuthoritative: authoritative,
            supportedDataVersion:
                supportedVersion
                ?? response.sourceDocumentVersion,
            result: .success(response)
        )
    }

    private func makeFailingSource(
        identifier: String,
        priority: Int,
        authoritative: Bool,
        version: String,
        error: MedicineKnowledgeError
    ) -> StubMedicineKnowledgeSource {
        StubMedicineKnowledgeSource(
            identifier: identifier,
            displayName: identifier,
            priority: priority,
            isAuthoritative: authoritative,
            supportedDataVersion: version,
            result: .failure(error)
        )
    }

    private func makeResponse(
        sourceIdentifier: String,
        version: String,
        activeIngredientIDs: [String] = [
            "acetaminophen",
        ],
        fetchedAt: Date = serviceTestDate
    ) -> MedicineKnowledgeSourceResponse {
        let reference = SourceReference(
            sourceName: sourceIdentifier,
            documentTitle:
                MedicineKnowledgeSafety.demoDisclaimer,
            optionalURL: nil,
            retrievedAt: fetchedAt,
            versionOrDate: version
        )
        let record = MedicineKnowledgeRecord(
            canonicalMedicineIdentifier:
                "medicine-acetaminophen",
            canonicalName: "Acetaminophen",
            aliases: ["Paracetamol"],
            activeIngredientIDs: activeIngredientIDs,
            category: .analgesic,
            warnings: [
                MedicineKnowledgeSafety.demoDisclaimer,
            ],
            contraindicationTags: [],
            dosageTextFromSource: nil,
            sourceIdentifier: sourceIdentifier,
            sourceReference: reference,
            sourceDocumentVersion: version,
            fetchedAt: fetchedAt,
            completeness: 1,
            validationStatus: .valid
        )
        return MedicineKnowledgeSourceResponse(
            sourceIdentifier: sourceIdentifier,
            records: [record],
            sourceReference: reference,
            sourceDocumentVersion: version,
            fetchedAt: fetchedAt,
            completeness: 1,
            validationStatus: .valid,
            validationMetadata:
                MedicineSourceValidationMetadata(
                    etag: #""\#(version)""#,
                    lastModified:
                        "Thu, 24 Jul 2025 00:00:00 GMT",
                    dataVersion: version
                )
        )
    }

    private func makeDemoMedicine() -> Medicine {
        Medicine(
            id: "medicine-acetaminophen",
            canonicalName: "Acetaminophen",
            aliases: ["Paracetamol"],
            activeIngredientIDs: ["acetaminophen"],
            medicineCategory: .analgesic,
            sourceReferences: [],
            dosageTextFromSource: nil,
            contraindicationTags: [],
            warnings: [
                MedicineKnowledgeSafety.demoDisclaimer,
            ],
            dataVersion: "demo-fixture-v1"
        )
    }

    private func assertThrows(
        _ expected: MedicineKnowledgeError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected MedicineKnowledgeError.")
        } catch let error as MedicineKnowledgeError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(type(of: error))")
        }
    }
}

private struct StubMedicineKnowledgeSource:
    MedicineKnowledgeSource,
    Sendable
{
    let identifier: String
    let displayName: String
    let priority: Int
    let isAuthoritative: Bool
    let supportedDataVersion: String
    let result:
        Result<
            MedicineKnowledgeSourceResponse,
            MedicineKnowledgeError
        >

    func search(
        query: MedicineKnowledgeSourceQuery
    ) async throws -> MedicineKnowledgeSourceResponse {
        try result.get()
    }

    func fetchMedicine(
        identifier: String
    ) async throws -> MedicineKnowledgeSourceResponse {
        try result.get()
    }
}

private final class MutableKnowledgeClock:
    Clock,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var date: Date

    init(date: Date) {
        self.date = date
    }

    func now() -> Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            date = date.addingTimeInterval(interval)
        }
    }
}

private let serviceTestDate = Date(
    timeIntervalSince1970: 1_753_315_200
)
private let primaryID = "test-primary-source"
private let secondaryID = "test-secondary-source"
