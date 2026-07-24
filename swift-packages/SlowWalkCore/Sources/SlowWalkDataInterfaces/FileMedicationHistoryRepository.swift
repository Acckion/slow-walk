import Foundation
import SlowWalkDomain

/// Actor-isolated JSON repository for medication-history records.
public actor FileMedicationHistoryRepository:
    MedicationHistoryRepository
{
    public static let fileName = "medication-history.json"
    public static let schemaVersion = 1

    private let file: JSONRepositoryFile<MedicationRecord>

    public init(
        baseDirectory: URL,
        uuidProvider: any UUIDProviding = SystemUUIDProvider()
    ) {
        file = JSONRepositoryFile(
            baseDirectory: baseDirectory,
            fileName: Self.fileName,
            schemaVersion: Self.schemaVersion,
            uuidProvider: uuidProvider
        )
    }

    public func fetch(id: UUID) async throws -> MedicationRecord? {
        try file.load().first { $0.id == id }
    }

    public func fetchAll() async throws -> [MedicationRecord] {
        try file.load().sorted(
            by: MedicationRecordDeduplicator.recordOrder
        )
    }

    public func fetch(
        within interval: DateInterval
    ) async throws -> [MedicationRecord] {
        try file.load().filter {
            $0.recordedAt >= interval.start
                && $0.recordedAt <= interval.end
        }
        .sorted(by: MedicationRecordDeduplicator.recordOrder)
    }

    public func append(_ record: MedicationRecord) async throws {
        var records = try loadOrEmpty()
        records.removeAll { $0.id == record.id }
        records.append(record)
        try write(records)
    }

    public func delete(id: UUID) async throws {
        var records = try file.load()
        guard records.contains(where: { $0.id == id }) else {
            throw DataInterfaceError.medicationRecordNotFound(id: id)
        }
        records.removeAll { $0.id == id }
        try write(records)
    }

    @discardableResult
    public func removeDuplicates() async throws -> Int {
        let result = MedicationRecordDeduplicator.deduplicate(
            try file.load()
        )
        try write(result.records)
        return result.removedCount
    }

    private func loadOrEmpty() throws -> [MedicationRecord] {
        do {
            return try file.load()
        } catch JSONRepositoryError.fileNotFound {
            return []
        }
    }

    private func write(_ records: [MedicationRecord]) throws {
        try file.write(
            records.sorted(
                by: MedicationRecordDeduplicator.recordOrder
            )
        )
    }
}
