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

    /// Looks up a name-resolution result for the current source-data version.
    ///
    /// A `.hit` reuses only medicine-name resolution. Callers must still build
    /// a fresh risk context and run the risk engine for every request.
    func cachedResolution(
        normalizedQuery: String,
        sourceDataVersion: String,
        now: Date
    ) async throws -> MedicineResolutionCacheLookup

    /// Stores a resolution using the cache actor's configured TTL policy.
    ///
    /// `normalizedQuery` must represent every normalized OCR query variant
    /// that contributed to the resolution. The actor computes `expiresAt`
    /// from `now` and its policy.
    func storeResolution(
        _ resolution: MedicineResolution,
        normalizedQuery: String,
        sourceDataVersion: String,
        now: Date
    ) async throws
}

/// Search boundary for canonical medicine data.
public protocol MedicineSearching: Sendable {
    func searchMedicines(matching query: String) async throws -> [Medicine]
}

/// Typed repository failures with actionable context.
public enum DataInterfaceError: Error, Sendable, Equatable {
    case invalidDateRange(start: Date, end: Date)
    case invalidNormalizedQuery
    case invalidSourceDataVersion
}
