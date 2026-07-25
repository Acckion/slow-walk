import Foundation
import SlowWalkDomain

/// Actor-isolated medication-history repository for demos and tests.
public actor InMemoryMedicationHistoryRepository: MedicationHistoryRepository {
    private var storage: [UUID: MedicationRecord]

    public init(initialRecords: [MedicationRecord] = []) {
        var initialStorage = [UUID: MedicationRecord]()
        for record in initialRecords {
            initialStorage[record.id] = record
        }
        storage = initialStorage
    }

    public func fetch(id: UUID) async throws -> MedicationRecord? {
        storage[id]
    }

    public func fetchAll() async throws -> [MedicationRecord] {
        return storage.values
            .sorted(by: Self.recordOrder)
    }

    public func fetch(
        within interval: DateInterval
    ) async throws -> [MedicationRecord] {
        storage.values.filter {
            $0.recordedAt >= interval.start
                && $0.recordedAt <= interval.end
        }
        .sorted(by: Self.recordOrder)
    }

    public func append(_ record: MedicationRecord) async throws {
        storage[record.id] = record
    }

    public func delete(id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw DataInterfaceError.medicationRecordNotFound(id: id)
        }
    }

    @discardableResult
    public func removeDuplicates() async throws -> Int {
        let result = MedicationRecordDeduplicator.deduplicate(
            Array(storage.values)
        )
        storage = Dictionary(
            uniqueKeysWithValues: result.records.map { ($0.id, $0) }
        )
        return result.removedCount
    }

    private static func recordOrder(
        _ lhs: MedicationRecord,
        _ rhs: MedicationRecord
    ) -> Bool {
        if lhs.recordedAt != rhs.recordedAt {
            return lhs.recordedAt < rhs.recordedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
