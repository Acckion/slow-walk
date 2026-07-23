import Foundation
import SlowWalkDomain

/// Read/write boundary for canonical medicine data.
public protocol MedicineRepository: Sendable {
    func medicine(id: String) async throws -> Medicine?
    func allMedicines() async throws -> [Medicine]
    func save(_ medicine: Medicine) async throws
}

/// Read/write boundary for user health profiles.
public protocol UserHealthProfileRepository: Sendable {
    func profile(id: UUID) async throws -> UserHealthProfile?
    func allProfiles() async throws -> [UserHealthProfile]
    func save(_ profile: UserHealthProfile) async throws
}

/// Read/write boundary for medication history.
public protocol MedicationHistoryRepository: Sendable {
    func record(id: UUID) async throws -> MedicationRecord?
    func records(from startDate: Date?, through endDate: Date?) async throws
        -> [MedicationRecord]
    func save(_ record: MedicationRecord) async throws
}

/// Cache boundary kept separate from the source-of-truth repository.
public protocol MedicineCache: Sendable {
    func cachedMedicine(id: String) async throws -> Medicine?
    func store(_ medicine: Medicine) async throws
    func removeMedicine(id: String) async throws
    func removeAll() async throws
}

/// Search boundary for canonical medicine data.
public protocol MedicineSearching: Sendable {
    func searchMedicines(matching query: String) async throws -> [Medicine]
}

/// Typed repository failures with actionable context.
public enum DataInterfaceError: Error, Sendable, Equatable {
    case invalidDateRange(start: Date, end: Date)
}
