import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import XCTest

final class FileRepositoryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testProfileCanBeSavedAndFetched() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = profileRepository(at: directory)
        let profile = makeProfile(token: 1)

        try await repository.save(profile)
        let fetched = try await repository.fetch(id: profile.id)
        let all = try await repository.fetchAll()

        XCTAssertEqual(fetched, profile)
        XCTAssertEqual(all, [profile])
    }

    func testProfileCanBeUpdated() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = profileRepository(at: directory)
        let original = makeProfile(token: 1)
        let updated = UserHealthProfile(
            id: original.id,
            age: original.age,
            allergies: ["updated-demo-allergy"],
            diagnosedConditions: original.diagnosedConditions,
            currentMedicineIngredientIDs:
                original.currentMedicineIngredientIDs,
            bodyMetrics: original.bodyMetrics,
            updatedAt: now,
            createdAt: original.createdAt,
            schemaVersion: original.schemaVersion
        )

        try await repository.save(original)
        try await repository.update(updated)
        let fetched = try await repository.fetch(id: original.id)

        XCTAssertEqual(fetched, updated)
    }

    func testProfileCanBeDeleted() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = profileRepository(at: directory)
        let profile = makeProfile(token: 1)

        try await repository.save(profile)
        try await repository.delete(id: profile.id)
        let fetched = try await repository.fetch(id: profile.id)
        let all = try await repository.fetchAll()

        XCTAssertNil(fetched)
        XCTAssertEqual(all, [])
    }

    func testMedicationHistoryCanBeSavedAndFetched() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = historyRepository(at: directory)
        let first = makeRecord(token: 1, offset: -120)
        let second = makeRecord(token: 2, offset: -60)

        try await repository.append(second)
        try await repository.append(first)
        let all = try await repository.fetchAll()
        let intervalRecords = try await repository.fetch(
            within: DateInterval(
                start: now.addingTimeInterval(-120),
                end: now.addingTimeInterval(-120)
            )
        )

        XCTAssertEqual(all, [first, second])
        XCTAssertEqual(intervalRecords, [first])
    }

    func testMissingFileHasTypedError() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = profileRepository(at: directory)

        do {
            _ = try await repository.fetchAll()
            XCTFail("Expected a typed missing-file error.")
        } catch {
            XCTAssertEqual(
                error as? JSONRepositoryError,
                .fileNotFound
            )
        }
    }

    func testEmptyFileHasTypedError() async throws {
        let directory = try preparedDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(
            to: directory.appendingPathComponent(
                FileUserHealthProfileRepository.fileName
            )
        )
        let repository = profileRepository(at: directory)

        do {
            _ = try await repository.fetchAll()
            XCTFail("Expected a typed empty-file error.")
        } catch {
            XCTAssertEqual(
                error as? JSONRepositoryError,
                .emptyFile
            )
        }
    }

    func testCorruptedJSONHasTypedError() async throws {
        let directory = try preparedDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"schemaVersion":"#.utf8).write(
            to: directory.appendingPathComponent(
                FileUserHealthProfileRepository.fileName
            )
        )
        let repository = profileRepository(at: directory)

        do {
            _ = try await repository.fetchAll()
            XCTFail("Expected a typed corrupted-JSON error.")
        } catch {
            XCTAssertEqual(
                error as? JSONRepositoryError,
                .corruptedJSON
            )
        }
    }

    func testUnsupportedFileSchemaHasTypedError() async throws {
        let directory = try preparedDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(
            #"{"records":[],"schemaVersion":99}"#.utf8
        ).write(
            to: directory.appendingPathComponent(
                FileUserHealthProfileRepository.fileName
            )
        )
        let repository = profileRepository(at: directory)

        do {
            _ = try await repository.fetchAll()
            XCTFail("Expected a typed schema error.")
        } catch {
            XCTAssertEqual(
                error as? JSONRepositoryError,
                .unsupportedSchemaVersion(found: 99)
            )
        }
    }

    func testAtomicReplacementLeavesValidFileAndNoStagingData()
        async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = profileRepository(at: directory)
        let original = makeProfile(token: 1)
        let updated = UserHealthProfile(
            id: original.id,
            age: original.age,
            allergies: ["replacement"],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: original.bodyMetrics,
            updatedAt: now,
            createdAt: original.createdAt
        )

        try await repository.save(original)
        try await repository.update(updated)
        let all = try await repository.fetchAll()

        XCTAssertEqual(all, [updated])
        let names = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )
        XCTAssertFalse(
            names.contains {
                $0.hasSuffix(".tmp") || $0.hasSuffix(".backup")
            }
        )
    }

    func testConcurrentProfileWritesArePredictable() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = profileRepository(at: directory)
        let profiles = (1 ... 8).map {
            makeProfile(token: UInt8($0))
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for profile in profiles {
                group.addTask {
                    try await repository.save(profile)
                }
            }
            try await group.waitForAll()
        }
        let storedIDs = try await repository.fetchAll().map(\.id)

        XCTAssertEqual(
            storedIDs,
            profiles.map(\.id).sorted {
                $0.uuidString < $1.uuidString
            }
        )
    }

    func testDuplicateRemovalIsExplicitAndStable() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = historyRepository(at: directory)
        let first = makeRecord(token: 1, offset: -120)
        let duplicate = makeRecord(token: 2, offset: -119)

        try await repository.append(first)
        try await repository.append(duplicate)
        let beforeCount = try await repository.fetchAll().count
        XCTAssertEqual(beforeCount, 2)

        let removed = try await repository.removeDuplicates()
        let remaining = try await repository.fetchAll()
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(remaining, [first])
    }

    func testTemporaryDirectoryCanBeCleanedAfterRepositoryUse()
        async throws {
        let directory = temporaryDirectory()
        let repository = profileRepository(at: directory)

        try await repository.save(makeProfile(token: 1))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directory.path)
        )

        try FileManager.default.removeItem(at: directory)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: directory.path)
        )
    }

    private func profileRepository(
        at directory: URL
    ) -> FileUserHealthProfileRepository {
        FileUserHealthProfileRepository(
            baseDirectory: directory,
            uuidProvider: FixedUUIDProvider(
                fixedUUID: stagingUUID
            )
        )
    }

    private func historyRepository(
        at directory: URL
    ) -> FileMedicationHistoryRepository {
        FileMedicationHistoryRepository(
            baseDirectory: directory,
            uuidProvider: FixedUUIDProvider(
                fixedUUID: stagingUUID
            )
        )
    }

    private var stagingUUID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 99
            )
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "slowwalk-\(UUID().uuidString)",
                isDirectory: true
            )
    }

    private func preparedDirectory() throws -> URL {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func makeProfile(token: UInt8) -> UserHealthProfile {
        UserHealthProfile(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, token
                )
            ),
            age: 70,
            allergies: ["demo-allergy"],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: BodyMetrics(
                systolicBloodPressure: 120,
                diastolicBloodPressure: 80,
                heartRate: 70,
                measuredAt: now.addingTimeInterval(-60),
                source: "demo_data"
            ),
            updatedAt: now.addingTimeInterval(-60)
        )
    }

    private func makeRecord(
        token: UInt8,
        offset: TimeInterval
    ) -> MedicationRecord {
        MedicationRecord(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 1, token
                )
            ),
            medicineID: "medicine-a",
            activeIngredientIDs: ["ingredient-a"],
            recordedAt: now.addingTimeInterval(offset),
            eventType: .confirmedIntake,
            source: .demoData
        )
    }
}
