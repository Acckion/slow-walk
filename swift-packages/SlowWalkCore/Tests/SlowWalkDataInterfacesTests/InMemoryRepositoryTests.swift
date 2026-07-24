import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import XCTest

final class InMemoryRepositoryTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_735_689_600)

    func testMedicineRepositoryReadsWritesAndReturnsDeterministicOrder() async throws {
        let medicineB = makeMedicine(id: "b", name: "Zulu")
        let medicineA = makeMedicine(id: "a", name: "Alpha")
        let repository = InMemoryMedicineRepository(
            initialMedicines: [medicineB, medicineA]
        )

        let fetched = try await repository.medicine(id: "a")
        let all = try await repository.allMedicines()

        XCTAssertEqual(fetched, medicineA)
        XCTAssertEqual(all.map(\.id), ["a", "b"])
    }

    func testMedicineRepositoryUpsertsDuplicateID() async throws {
        let original = makeMedicine(id: "a", name: "Original")
        let replacement = makeMedicine(id: "a", name: "Replacement")
        let repository = InMemoryMedicineRepository(
            initialMedicines: [original]
        )

        try await repository.save(replacement)
        let fetched = try await repository.medicine(id: "a")
        let all = try await repository.allMedicines()

        XCTAssertEqual(fetched, replacement)
        XCTAssertEqual(all.count, 1)
    }

    func testMedicineSearchMatchesAliasesCaseInsensitively() async throws {
        let repository = InMemoryMedicineRepository(
            initialMedicines: [
                makeMedicine(id: "a", name: "Alpha", aliases: ["Helpful Alias"]),
                makeMedicine(id: "b", name: "Beta"),
            ]
        )

        let matches = try await repository.searchMedicines(
            matching: " helpful "
        )

        XCTAssertEqual(matches.map(\.id), ["a"])
    }

    func testUserProfileRepositoryReadsAndWrites() async throws {
        let profile = makeProfile(lastByte: 1)
        let repository = InMemoryUserHealthProfileRepository()

        try await repository.save(profile)
        let fetched = try await repository.profile(id: profile.id)
        let all = try await repository.allProfiles()

        XCTAssertEqual(fetched, profile)
        XCTAssertEqual(all, [profile])
    }

    func testMedicationHistoryRangeIsInclusiveAndSorted() async throws {
        let start = timestamp.addingTimeInterval(-2 * 24 * 60 * 60)
        let end = timestamp
        let records = [
            makeRecord(lastByte: 3, at: end),
            makeRecord(lastByte: 1, at: start),
            makeRecord(
                lastByte: 2,
                at: timestamp.addingTimeInterval(-24 * 60 * 60)
            ),
            makeRecord(lastByte: 4, at: end.addingTimeInterval(1)),
        ]
        let repository = InMemoryMedicationHistoryRepository(
            initialRecords: records
        )

        let result = try await repository.records(
            from: start,
            through: end
        )

        XCTAssertEqual(
            result.map(\.id),
            [records[1].id, records[2].id, records[0].id]
        )
    }

    func testMedicationHistoryRejectsReversedDateRange() async {
        let repository = InMemoryMedicationHistoryRepository()
        let start = timestamp
        let end = timestamp.addingTimeInterval(-1)

        do {
            _ = try await repository.records(from: start, through: end)
            XCTFail("Expected invalidDateRange.")
        } catch let error as DataInterfaceError {
            XCTAssertEqual(
                error,
                .invalidDateRange(start: start, end: end)
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMedicationHistoryUpsertsDuplicateRecordID() async throws {
        let original = makeRecord(lastByte: 1, at: timestamp)
        let replacement = MedicationRecord(
            id: original.id,
            medicineID: "replacement",
            activeIngredientIDs: ["ingredient-b"],
            recordedAt: timestamp.addingTimeInterval(1),
            eventType: .reported,
            source: .demoData
        )
        let repository = InMemoryMedicationHistoryRepository(
            initialRecords: [original]
        )

        try await repository.save(replacement)
        let fetched = try await repository.record(id: original.id)
        let all = try await repository.records(from: nil, through: nil)

        XCTAssertEqual(fetched, replacement)
        XCTAssertEqual(all, [replacement])
    }

    func testMedicineCacheStoresRemovesAndClears() async throws {
        let medicineA = makeMedicine(id: "a", name: "Alpha")
        let medicineB = makeMedicine(id: "b", name: "Beta")
        let cache = InMemoryMedicineCache(initialMedicines: [medicineA])

        try await cache.store(medicineB)
        let cachedB = try await cache.cachedMedicine(id: "b")
        XCTAssertEqual(cachedB, medicineB)

        try await cache.removeMedicine(id: "a")
        let removedA = try await cache.cachedMedicine(id: "a")
        XCTAssertNil(removedA)

        try await cache.removeAll()
        let removedB = try await cache.cachedMedicine(id: "b")
        XCTAssertNil(removedB)
    }

    func testActorRepositoryHandlesConcurrentWrites() async throws {
        let repository = InMemoryMedicineRepository()
        let medicines = (0 ..< 20).map { index in
            makeMedicine(id: "medicine-\(index)", name: "Medicine \(index)")
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for medicine in medicines {
                group.addTask {
                    try await repository.save(medicine)
                }
            }
            try await group.waitForAll()
        }

        let all = try await repository.allMedicines()
        XCTAssertEqual(all.count, medicines.count)
        XCTAssertEqual(Set(all.map(\.id)), Set(medicines.map(\.id)))
    }

    func testFixedProvidersAreDeterministic() {
        let uuid = fixedUUID(lastByte: 9)
        let dateProvider = FixedClock(fixedDate: timestamp)
        let uuidProvider = FixedUUIDProvider(fixedUUID: uuid)

        XCTAssertEqual(dateProvider.now(), timestamp)
        XCTAssertEqual(dateProvider.now(), timestamp)
        XCTAssertEqual(uuidProvider.makeUUID(), uuid)
        XCTAssertEqual(uuidProvider.makeUUID(), uuid)
    }

    private func makeMedicine(
        id: String,
        name: String,
        aliases: [String] = []
    ) -> Medicine {
        Medicine(
            id: id,
            canonicalName: name,
            aliases: aliases,
            activeIngredientIDs: ["ingredient-a"],
            medicineCategory: .other,
            sourceReferences: [],
            dosageTextFromSource: nil,
            contraindicationTags: []
        )
    }

    private func makeProfile(lastByte: UInt8) -> UserHealthProfile {
        UserHealthProfile(
            id: fixedUUID(lastByte: lastByte),
            age: 70,
            allergies: [],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: nil,
            updatedAt: timestamp
        )
    }

    private func makeRecord(
        lastByte: UInt8,
        at date: Date
    ) -> MedicationRecord {
        MedicationRecord(
            id: fixedUUID(lastByte: lastByte),
            medicineID: "medicine-a",
            activeIngredientIDs: ["ingredient-a"],
            recordedAt: date,
            eventType: .taken,
            source: .manualEntry
        )
    }

    private func fixedUUID(lastByte: UInt8) -> UUID {
        UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, lastByte)
        )
    }
}
