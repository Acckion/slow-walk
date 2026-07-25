import Foundation
import SlowWalkDomain
import SlowWalkMedicineKnowledge

/// API v1 request for a normalized, server-governed medicine lookup.
public struct MedicineKnowledgeSearchRequestDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let normalizedQuery: String
    public let requestID: UUID
    public let apiVersion: String

    public init(
        normalizedQuery: String,
        requestID: UUID,
        apiVersion: String
    ) {
        self.normalizedQuery = normalizedQuery
        self.requestID = requestID
        self.apiVersion = apiVersion
    }
}

/// API v1 response retaining source, cache, and data-quality evidence.
public struct MedicineKnowledgeSearchResponseDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let requestID: UUID
    public let normalizedQuery: String
    public let candidates: [MedicineKnowledgeCandidate]
    public let sourceStatus: MedicineKnowledgeSourceStatus
    public let cacheStatus: MedicineKnowledgeCacheStatus
    public let completeness: Double
    public let sourceReferences: [SourceReference]
    public let warnings: [MedicineKnowledgeWarning]
    public let sourceVersions: [String: String]
    public let generatedAt: Date
    public let isOffline: Bool
    public let apiVersion: String

    public init(
        requestID: UUID,
        result: MedicineKnowledgeSearchResult,
        apiVersion: String
    ) {
        self.requestID = requestID
        normalizedQuery = result.normalizedQuery
        candidates = result.candidates
        sourceStatus = result.sourceStatus
        cacheStatus = result.cacheStatus
        completeness = result.completeness
        sourceReferences = result.sourceReferences
        warnings = result.warnings
        sourceVersions = result.sourceVersions
        generatedAt = result.generatedAt
        isOffline = result.isOffline
        self.apiVersion = apiVersion
    }
}
