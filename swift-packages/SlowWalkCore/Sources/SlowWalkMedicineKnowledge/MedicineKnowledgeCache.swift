import Foundation

public struct MedicineKnowledgeCachePolicy:
    Sendable,
    Equatable
{
    public static let demo = MedicineKnowledgeCachePolicy(
        validatedTimeToLive: 15 * 60,
        offlineGracePeriod: 24 * 60 * 60
    )

    public let timeToLive: TimeInterval
    public let offlineGracePeriod: TimeInterval

    public init(
        timeToLive: TimeInterval,
        offlineGracePeriod: TimeInterval
    ) throws {
        guard timeToLive.isFinite, timeToLive > 0 else {
            throw MedicineKnowledgeCachePolicyError
                .invalidTimeToLive
        }
        guard offlineGracePeriod.isFinite,
            offlineGracePeriod >= 0
        else {
            throw MedicineKnowledgeCachePolicyError
                .invalidOfflineGracePeriod
        }
        self.timeToLive = timeToLive
        self.offlineGracePeriod = offlineGracePeriod
    }

    fileprivate func expiresAt(storedAt: Date) -> Date {
        storedAt.addingTimeInterval(timeToLive)
    }

    fileprivate func offlineUseUntil(storedAt: Date) -> Date {
        expiresAt(storedAt: storedAt).addingTimeInterval(
            offlineGracePeriod
        )
    }

    private init(
        validatedTimeToLive: TimeInterval,
        offlineGracePeriod: TimeInterval
    ) {
        timeToLive = validatedTimeToLive
        self.offlineGracePeriod = offlineGracePeriod
    }
}

public enum MedicineKnowledgeCachePolicyError:
    Error,
    Sendable,
    Equatable
{
    case invalidTimeToLive
    case invalidOfflineGracePeriod
}

public actor InMemoryMedicineKnowledgeCache:
    MedicineKnowledgeCaching
{
    private let policy: MedicineKnowledgeCachePolicy
    private var storage: [String: MedicineKnowledgeCacheEntry]

    public init(
        policy: MedicineKnowledgeCachePolicy = .demo
    ) {
        self.policy = policy
        storage = [:]
    }

    public func lookup(
        normalizedQuery: String,
        now: Date
    ) async throws -> MedicineKnowledgeCacheLookup {
        let key = try Self.cacheKey(normalizedQuery)
        guard let entry = storage[key] else {
            return MedicineKnowledgeCacheLookup(status: .miss)
        }
        guard now >= entry.expiresAt else {
            return MedicineKnowledgeCacheLookup(
                status: .hit,
                entry: entry,
                canUseOffline: true
            )
        }
        return MedicineKnowledgeCacheLookup(
            status: .expired,
            entry: entry,
            canUseOffline: now <= entry.offlineUseUntil
        )
    }

    public func store(
        result: MedicineKnowledgeSearchResult,
        sourceResponses: [String: MedicineKnowledgeSourceResponse],
        now: Date
    ) async throws {
        let key = try Self.cacheKey(result.normalizedQuery)
        storage[key] = MedicineKnowledgeCacheEntry(
            normalizedQuery: key,
            sourceResponses: sourceResponses,
            result: result,
            storedAt: now,
            expiresAt: policy.expiresAt(storedAt: now),
            offlineUseUntil: policy.offlineUseUntil(
                storedAt: now
            )
        )
    }

    public func remove(
        normalizedQuery: String
    ) async throws {
        let key = try Self.cacheKey(normalizedQuery)
        storage[key] = nil
    }

    public func removeAll() async throws {
        storage.removeAll(keepingCapacity: false)
    }

    private static func cacheKey(
        _ value: String
    ) throws -> String {
        let key = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !key.isEmpty else {
            throw MedicineKnowledgeError.malformedRequest
        }
        return key
    }
}
