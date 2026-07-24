import Foundation
import SlowWalkDomain

/// Actor-isolated cache for demos and tests.
public actor InMemoryMedicineCache: MedicineCache {
    private var storage: [String: Medicine]
    private var resolutionStorage: [String: MedicineResolutionCacheEntry]
    private let resolutionPolicy: MedicineResolutionCachePolicy

    public init(
        initialMedicines: [Medicine] = [],
        resolutionPolicy: MedicineResolutionCachePolicy = .demo
    ) {
        var initialStorage = [String: Medicine]()
        for medicine in initialMedicines {
            initialStorage[medicine.id] = medicine
        }
        storage = initialStorage
        resolutionStorage = [:]
        self.resolutionPolicy = resolutionPolicy
    }

    public func cachedMedicine(id: String) async throws -> Medicine? {
        storage[id]
    }

    public func store(_ medicine: Medicine) async throws {
        storage[medicine.id] = medicine
    }

    public func removeMedicine(id: String) async throws {
        storage[id] = nil
    }

    public func removeAll() async throws {
        storage.removeAll(keepingCapacity: false)
        resolutionStorage.removeAll(keepingCapacity: false)
    }

    public func cachedResolution(
        normalizedQuery: String,
        sourceDataVersion: String,
        now: Date
    ) async throws -> MedicineResolutionCacheLookup {
        let queryKey = try Self.validatedQuery(normalizedQuery)
        let requestedVersion = try Self.validatedVersion(sourceDataVersion)

        guard let entry = resolutionStorage[queryKey] else {
            return MedicineResolutionCacheLookup(status: .miss)
        }

        // A changed source version takes precedence over expiration so callers
        // can observe why the current catalog invalidated the cached value.
        guard entry.sourceDataVersion == requestedVersion else {
            resolutionStorage[queryKey] = nil
            return MedicineResolutionCacheLookup(status: .sourceVersionChanged)
        }

        guard now < entry.expiresAt else {
            resolutionStorage[queryKey] = nil
            return MedicineResolutionCacheLookup(status: .expired)
        }

        return MedicineResolutionCacheLookup(status: .hit, entry: entry)
    }

    public func storeResolution(
        _ resolution: MedicineResolution,
        normalizedQuery: String,
        sourceDataVersion: String,
        now: Date
    ) async throws {
        let queryKey = try Self.validatedQuery(normalizedQuery)
        let version = try Self.validatedVersion(sourceDataVersion)
        let entry = MedicineResolutionCacheEntry(
            normalizedQuery: queryKey,
            sourceDataVersion: version,
            resolution: resolution,
            storedAt: now,
            expiresAt: resolutionPolicy.expirationDate(storedAt: now)
        )
        resolutionStorage[queryKey] = entry
    }

    private static func validatedQuery(_ value: String) throws -> String {
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw DataInterfaceError.invalidNormalizedQuery
        }
        return query
    }

    private static func validatedVersion(_ value: String) throws -> String {
        let version = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else {
            throw DataInterfaceError.invalidSourceDataVersion
        }
        return version
    }
}
