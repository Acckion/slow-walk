import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicineKnowledge
import XCTest

final class MedicineKnowledgeArchitectureTests: XCTestCase {
    func testDemoDisclaimerIsExplicit() {
        XCTAssertEqual(
            MedicineKnowledgeSafety.demoDisclaimer,
            "DEMO DATA — NOT FOR CLINICAL USE"
        )
    }

    func testSourcePolicyRejectsNonWhitelistedSource() throws {
        let source = TestMedicineKnowledgeSource(
            identifier: "untrusted-source",
            priority: 1,
            isAuthoritative: false
        )

        XCTAssertThrowsError(
            try SourcePolicy.demo.orderedSources([source])
        ) { error in
            XCTAssertEqual(
                error as? SourcePolicyError,
                .sourceNotWhitelisted("untrusted-source")
            )
        }
    }

    func testSourcePolicyOrdersAuthoritativeSourceFirst()
        throws
    {
        let clock = FixedClock(fixedDate: testDate)
        let transport = DemoMockHTTPTransport(
            medicines: [],
            fetchedAt: testDate
        )
        let authoritative = try MockAuthoritativeMedicineSource(
            transport: transport,
            clock: clock
        )
        let secondary = try MockSecondaryMedicineSource(
            transport: transport,
            clock: clock
        )

        let ordered = try SourcePolicy.demo.orderedSources([
            secondary,
            authoritative,
        ])

        XCTAssertEqual(
            ordered.map(\.identifier),
            [
                MockAuthoritativeMedicineSource.identifier,
                MockSecondaryMedicineSource.identifier,
            ]
        )
    }

    func testCachePreservesExpiredEntryForRevalidation()
        async throws
    {
        let policy = try MedicineKnowledgeCachePolicy(
            timeToLive: 60,
            offlineGracePeriod: 120
        )
        let cache = InMemoryMedicineKnowledgeCache(
            policy: policy
        )
        let result = makeSearchResult()

        try await cache.store(
            result: result,
            sourceResponses: [:],
            now: testDate
        )

        let fresh = try await cache.lookup(
            normalizedQuery: "  ACETAMINOPHEN ",
            now: testDate.addingTimeInterval(59)
        )
        let expired = try await cache.lookup(
            normalizedQuery: "acetaminophen",
            now: testDate.addingTimeInterval(61)
        )
        let outsideOfflineGrace = try await cache.lookup(
            normalizedQuery: "acetaminophen",
            now: testDate.addingTimeInterval(181)
        )

        XCTAssertEqual(fresh.status, .hit)
        XCTAssertNotNil(fresh.entry)
        XCTAssertEqual(expired.status, .expired)
        XCTAssertNotNil(expired.entry)
        XCTAssertTrue(expired.canUseOffline)
        XCTAssertEqual(
            outsideOfflineGrace.status,
            .expired
        )
        XCTAssertNotNil(outsideOfflineGrace.entry)
        XCTAssertFalse(outsideOfflineGrace.canUseOffline)
    }

    func testStructuredSearchResultRoundTripsThroughJSON()
        throws
    {
        let result = makeSearchResult()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoded = try encoder.encode(result)
        let decoded = try decoder.decode(
            MedicineKnowledgeSearchResult.self,
            from: encoded
        )

        XCTAssertEqual(decoded, result)
        XCTAssertEqual(
            decoded.sourceDataVersion,
            "mock-authoritative-medicine-source=demo-authoritative-v1"
        )
    }

    private func makeSearchResult()
        -> MedicineKnowledgeSearchResult
    {
        MedicineKnowledgeSearchResult(
            normalizedQuery: "acetaminophen",
            candidates: [],
            sourceStatus: .authoritative,
            cacheStatus: .miss,
            completeness: 1,
            sourceReferences: [],
            warnings: [],
            sourceVersions: [
                MockAuthoritativeMedicineSource.identifier:
                    MockAuthoritativeMedicineSource.dataVersion,
            ],
            generatedAt: testDate,
            isOffline: false
        )
    }
}

private struct TestMedicineKnowledgeSource:
    MedicineKnowledgeSource,
    Sendable
{
    let identifier: String
    let priority: Int
    let isAuthoritative: Bool

    var displayName: String {
        identifier
    }

    var supportedDataVersion: String {
        "test-v1"
    }

    func search(
        query: MedicineKnowledgeSourceQuery
    ) async throws -> MedicineKnowledgeSourceResponse {
        throw MedicineKnowledgeError.medicineNotFound
    }

    func fetchMedicine(
        identifier: String
    ) async throws -> MedicineKnowledgeSourceResponse {
        throw MedicineKnowledgeError.medicineNotFound
    }
}

private let testDate = Date(
    timeIntervalSince1970: 1_753_315_200
)
