import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import XCTest

final class MedicineResolutionCacheTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testMissingResolutionReportsMiss() async throws {
        let cache = InMemoryMedicineCache()

        let lookup = try await cache.cachedResolution(
            normalizedQuery: "demo relief alpha",
            sourceDataVersion: "catalog-v1",
            now: now
        )

        XCTAssertEqual(lookup.status, .miss)
        XCTAssertNil(lookup.entry)
        XCTAssertNil(lookup.resolution)
    }

    func testStoredResolutionHitsBeforeTTLAndExposesEntryMetadata() async throws {
        let policy = try MedicineResolutionCachePolicy(timeToLive: 60)
        let cache = InMemoryMedicineCache(resolutionPolicy: policy)
        let resolution = makeResolution(normalizedQuery: "demo relief alpha")

        try await cache.storeResolution(
            resolution,
            normalizedQuery: "demo relief alpha",
            sourceDataVersion: "catalog-v1",
            now: now
        )
        let lookup = try await cache.cachedResolution(
            normalizedQuery: "demo relief alpha",
            sourceDataVersion: "catalog-v1",
            now: now.addingTimeInterval(59)
        )

        XCTAssertEqual(lookup.status, .hit)
        XCTAssertEqual(lookup.resolution, resolution)
        XCTAssertEqual(lookup.entry?.normalizedQuery, "demo relief alpha")
        XCTAssertEqual(lookup.entry?.sourceDataVersion, "catalog-v1")
        XCTAssertEqual(lookup.entry?.storedAt, now)
        XCTAssertEqual(
            lookup.entry?.expiresAt,
            now.addingTimeInterval(60)
        )
    }

    func testExactTTLBoundaryReportsExpiredAndEvictsEntry() async throws {
        let policy = try MedicineResolutionCachePolicy(timeToLive: 60)
        let cache = InMemoryMedicineCache(resolutionPolicy: policy)
        try await cache.storeResolution(
            makeResolution(normalizedQuery: "demo fever amber"),
            normalizedQuery: "demo fever amber",
            sourceDataVersion: "catalog-v1",
            now: now
        )

        let expired = try await cache.cachedResolution(
            normalizedQuery: "demo fever amber",
            sourceDataVersion: "catalog-v1",
            now: now.addingTimeInterval(60)
        )
        let afterEviction = try await cache.cachedResolution(
            normalizedQuery: "demo fever amber",
            sourceDataVersion: "catalog-v1",
            now: now.addingTimeInterval(61)
        )

        XCTAssertEqual(expired.status, .expired)
        XCTAssertNil(expired.resolution)
        XCTAssertEqual(afterEviction.status, .miss)
    }

    func testSourceVersionChangeReportsStatusAndEvictsEntry() async throws {
        let policy = try MedicineResolutionCachePolicy(timeToLive: 60)
        let cache = InMemoryMedicineCache(resolutionPolicy: policy)
        try await cache.storeResolution(
            makeResolution(normalizedQuery: "demo cold north"),
            normalizedQuery: "demo cold north",
            sourceDataVersion: "catalog-v1",
            now: now
        )

        let changed = try await cache.cachedResolution(
            normalizedQuery: "demo cold north",
            sourceDataVersion: "catalog-v2",
            now: now.addingTimeInterval(1)
        )
        let afterEviction = try await cache.cachedResolution(
            normalizedQuery: "demo cold north",
            sourceDataVersion: "catalog-v1",
            now: now.addingTimeInterval(2)
        )

        XCTAssertEqual(changed.status, .sourceVersionChanged)
        XCTAssertNil(changed.resolution)
        XCTAssertEqual(afterEviction.status, .miss)
    }

    func testSourceVersionChangeTakesPrecedenceOverExpiration() async throws {
        let policy = try MedicineResolutionCachePolicy(timeToLive: 1)
        let cache = InMemoryMedicineCache(resolutionPolicy: policy)
        try await cache.storeResolution(
            makeResolution(normalizedQuery: "demo allergy blue"),
            normalizedQuery: "demo allergy blue",
            sourceDataVersion: "catalog-v1",
            now: now
        )

        let lookup = try await cache.cachedResolution(
            normalizedQuery: "demo allergy blue",
            sourceDataVersion: "catalog-v2",
            now: now.addingTimeInterval(2)
        )

        XCTAssertEqual(lookup.status, .sourceVersionChanged)
    }

    func testRemoveAllClearsLegacyMedicinesAndResolutionEntries() async throws {
        let medicine = makeMedicine()
        let cache = InMemoryMedicineCache(initialMedicines: [medicine])
        try await cache.storeResolution(
            makeResolution(
                normalizedQuery: "demo relief alpha",
                medicine: medicine
            ),
            normalizedQuery: "demo relief alpha",
            sourceDataVersion: "catalog-v1",
            now: now
        )

        try await cache.removeAll()

        let cachedMedicine = try await cache.cachedMedicine(id: medicine.id)
        let cachedResolution = try await cache.cachedResolution(
            normalizedQuery: "demo relief alpha",
            sourceDataVersion: "catalog-v1",
            now: now
        )
        XCTAssertNil(cachedMedicine)
        XCTAssertEqual(cachedResolution.status, .miss)
    }

    func testInvalidCacheInputsAreRejected() async throws {
        let cache = InMemoryMedicineCache()
        let resolution = makeResolution(normalizedQuery: " ")

        do {
            try await cache.storeResolution(
                resolution,
                normalizedQuery: " ",
                sourceDataVersion: "catalog-v1",
                now: now
            )
            XCTFail("Expected invalidNormalizedQuery.")
        } catch let error as DataInterfaceError {
            XCTAssertEqual(error, .invalidNormalizedQuery)
        }

        do {
            _ = try await cache.cachedResolution(
                normalizedQuery: "demo relief alpha",
                sourceDataVersion: " ",
                now: now
            )
            XCTFail("Expected invalidSourceDataVersion.")
        } catch let error as DataInterfaceError {
            XCTAssertEqual(error, .invalidSourceDataVersion)
        }
    }

    func testCachePolicyRejectsNonPositiveAndNonFiniteTTL() {
        XCTAssertThrowsError(
            try MedicineResolutionCachePolicy(timeToLive: 0)
        ) { error in
            XCTAssertEqual(
                error as? MedicineResolutionCachePolicyError,
                .nonPositiveTimeToLive
            )
        }
        XCTAssertThrowsError(
            try MedicineResolutionCachePolicy(timeToLive: .infinity)
        ) { error in
            XCTAssertEqual(
                error as? MedicineResolutionCachePolicyError,
                .nonFiniteTimeToLive
            )
        }
    }

    private func makeResolution(
        normalizedQuery: String,
        medicine: Medicine? = nil
    ) -> MedicineResolution {
        let resolvedMedicine = medicine ?? makeMedicine()
        return MedicineResolution(
            status: .resolved,
            candidates: [
                MedicineCandidate(
                    medicine: resolvedMedicine,
                    matchScore: 1,
                    matchedAlias: nil,
                    matchReasons: [.canonicalExact]
                ),
            ],
            selectedMedicine: resolvedMedicine,
            evidence: MedicineResolutionEvidence(
                recognizedTexts: [resolvedMedicine.canonicalName],
                normalizedText: normalizedQuery,
                normalizedQuery: normalizedQuery,
                languageCode: "en",
                rawConfidence: 1,
                dosageForms: [],
                removedSpecifications: [],
                discardedNoise: [],
                matcherVersion: "matcher-v1",
                sourceDataVersions: [resolvedMedicine.dataVersion]
            ),
            requiresUserConfirmation: false
        )
    }

    private func makeMedicine() -> Medicine {
        Medicine(
            id: "demo-relief-alpha",
            canonicalName: "Demo Relief Alpha",
            aliases: ["Alpha Relief Demo"],
            activeIngredientIDs: ["demo-ingredient-alpha"],
            medicineCategory: .analgesic,
            sourceReferences: [],
            dosageTextFromSource: nil,
            contraindicationTags: [],
            warnings: [DemoMedicineCatalogPolicy.requiredDisclaimer],
            dataVersion: "catalog-v1"
        )
    }
}
