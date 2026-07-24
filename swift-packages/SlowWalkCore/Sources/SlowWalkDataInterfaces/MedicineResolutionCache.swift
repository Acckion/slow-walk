import Foundation
import SlowWalkDomain

/// Technical lifetime policy for cached name-resolution results.
///
/// This TTL controls recomputation only. It is not a clinical-validity period.
public struct MedicineResolutionCachePolicy: Sendable, Equatable {
    public static let demo = MedicineResolutionCachePolicy(
        validatedTimeToLive: 15 * 60
    )

    public let timeToLive: TimeInterval

    public init(timeToLive: TimeInterval) throws {
        guard timeToLive.isFinite else {
            throw MedicineResolutionCachePolicyError.nonFiniteTimeToLive
        }
        guard timeToLive > 0 else {
            throw MedicineResolutionCachePolicyError.nonPositiveTimeToLive
        }
        self.timeToLive = timeToLive
    }

    func expirationDate(storedAt: Date) -> Date {
        storedAt.addingTimeInterval(timeToLive)
    }

    private init(validatedTimeToLive: TimeInterval) {
        timeToLive = validatedTimeToLive
    }
}

public enum MedicineResolutionCachePolicyError: Error, Sendable, Equatable {
    case nonFiniteTimeToLive
    case nonPositiveTimeToLive
}

/// Immutable metadata and value stored for one normalized medicine query.
///
/// Cache implementations are responsible for applying their configured TTL
/// when calculating `expiresAt`.
public struct MedicineResolutionCacheEntry: Sendable, Equatable {
    public let normalizedQuery: String
    public let sourceDataVersion: String
    public let resolution: MedicineResolution
    public let storedAt: Date
    public let expiresAt: Date

    public init(
        normalizedQuery: String,
        sourceDataVersion: String,
        resolution: MedicineResolution,
        storedAt: Date,
        expiresAt: Date
    ) {
        self.normalizedQuery = normalizedQuery
        self.sourceDataVersion = sourceDataVersion
        self.resolution = resolution
        self.storedAt = storedAt
        self.expiresAt = expiresAt
    }
}

/// Observable result of consulting the resolution cache.
///
/// `entry` is populated only for `.hit`; expired or version-mismatched values
/// are never exposed for use.
public struct MedicineResolutionCacheLookup: Sendable, Equatable {
    public let status: MedicineResolutionCacheStatus
    public let entry: MedicineResolutionCacheEntry?

    public var resolution: MedicineResolution? {
        entry?.resolution
    }

    public init(
        status: MedicineResolutionCacheStatus,
        entry: MedicineResolutionCacheEntry? = nil
    ) {
        self.status = status
        self.entry = entry
    }
}
