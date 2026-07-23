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

    public func record(id: UUID) async throws -> MedicationRecord? {
        storage[id]
    }

    public func records(
        from startDate: Date?,
        through endDate: Date?
    ) async throws -> [MedicationRecord] {
        if let startDate, let endDate, startDate > endDate {
            throw DataInterfaceError.invalidDateRange(
                start: startDate,
                end: endDate
            )
        }

        return storage.values
            .filter { record in
                let isAfterStart = startDate.map { record.recordedAt >= $0 } ?? true
                let isBeforeEnd = endDate.map { record.recordedAt <= $0 } ?? true
                return isAfterStart && isBeforeEnd
            }
            .sorted(by: Self.recordOrder)
    }

    public func save(_ record: MedicationRecord) async throws {
        storage[record.id] = record
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
