import Foundation
import SlowWalkDomain

public enum MedicineKnowledgeSafety {
    public static let demoDisclaimer =
        "DEMO DATA — NOT FOR CLINICAL USE"
}

public enum MedicineKnowledgeValidationStatus:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case valid
    case warning
    case invalid
    case notModified = "not_modified"
}

public enum MedicineKnowledgeSourceStatus:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case authoritative
    case corroborated
    case partial
    case conflicting
    case staleOffline = "stale_offline"
    case unavailable
}

public enum MedicineKnowledgeCacheStatus:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case miss
    case hit
    case expired
    case revalidated
    case staleOffline = "stale_offline"
    case sourceVersionChanged = "source_version_changed"
    case notStored = "not_stored"
}

public enum MedicineKnowledgeWarningCode:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case sourceConflict = "SOURCE_CONFLICT"
    case sourceUnavailable = "KNOWLEDGE_SOURCE_UNAVAILABLE"
    case sourceTimeout = "KNOWLEDGE_SOURCE_TIMEOUT"
    case invalidSourceResponse = "INVALID_SOURCE_RESPONSE"
    case sourceVersionUnsupported = "SOURCE_VERSION_UNSUPPORTED"
    case offlineCacheUsed = "OFFLINE_CACHE_USED"
    case offlineCacheUnavailable = "OFFLINE_CACHE_UNAVAILABLE"
    case sourceStale = "SOURCE_STALE"
    case authoritativeSourceMissing = "AUTHORITATIVE_SOURCE_MISSING"
    case dosageSuppressed = "DOSAGE_SUPPRESSED"
    case sourceNotWhitelisted = "SOURCE_NOT_WHITELISTED"
}

public struct MedicineKnowledgeWarning:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let code: MedicineKnowledgeWarningCode
    public let message: String
    public let sourceIdentifiers: [String]

    public init(
        code: MedicineKnowledgeWarningCode,
        message: String,
        sourceIdentifiers: [String] = []
    ) {
        self.code = code
        self.message = message
        self.sourceIdentifiers = sourceIdentifiers
    }
}

public struct MedicineSourceValidationMetadata:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let etag: String?
    public let lastModified: String?
    public let dataVersion: String?

    public init(
        etag: String? = nil,
        lastModified: String? = nil,
        dataVersion: String? = nil
    ) {
        self.etag = etag
        self.lastModified = lastModified
        self.dataVersion = dataVersion
    }
}

public struct MedicineKnowledgeQuery:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let normalizedQuery: String

    public init(normalizedQuery: String) {
        self.normalizedQuery = normalizedQuery
    }
}

public struct MedicineKnowledgeSourceQuery:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let normalizedQuery: String
    public let validationMetadata: MedicineSourceValidationMetadata?

    public init(
        normalizedQuery: String,
        validationMetadata: MedicineSourceValidationMetadata? = nil
    ) {
        self.normalizedQuery = normalizedQuery
        self.validationMetadata = validationMetadata
    }
}

public struct MedicineKnowledgeRecord:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let canonicalMedicineIdentifier: String
    public let canonicalName: String
    public let aliases: [String]
    public let activeIngredientIDs: [String]
    public let category: MedicineCategory
    public let warnings: [String]
    public let contraindicationTags: [String]
    public let dosageTextFromSource: String?
    public let sourceIdentifier: String
    public let sourceReference: SourceReference
    public let sourceDocumentVersion: String
    public let fetchedAt: Date
    public let completeness: Double
    public let validationStatus: MedicineKnowledgeValidationStatus

    public init(
        canonicalMedicineIdentifier: String,
        canonicalName: String,
        aliases: [String],
        activeIngredientIDs: [String],
        category: MedicineCategory,
        warnings: [String],
        contraindicationTags: [String],
        dosageTextFromSource: String?,
        sourceIdentifier: String,
        sourceReference: SourceReference,
        sourceDocumentVersion: String,
        fetchedAt: Date,
        completeness: Double,
        validationStatus: MedicineKnowledgeValidationStatus
    ) {
        self.canonicalMedicineIdentifier =
            canonicalMedicineIdentifier
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.activeIngredientIDs = activeIngredientIDs
        self.category = category
        self.warnings = warnings
        self.contraindicationTags = contraindicationTags
        self.dosageTextFromSource = dosageTextFromSource
        self.sourceIdentifier = sourceIdentifier
        self.sourceReference = sourceReference
        self.sourceDocumentVersion = sourceDocumentVersion
        self.fetchedAt = fetchedAt
        self.completeness = completeness
        self.validationStatus = validationStatus
    }
}

public struct MedicineKnowledgeSourceResponse:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let sourceIdentifier: String
    public let records: [MedicineKnowledgeRecord]
    public let sourceReference: SourceReference
    public let sourceDocumentVersion: String
    public let fetchedAt: Date
    public let completeness: Double
    public let validationStatus: MedicineKnowledgeValidationStatus
    public let validationMetadata: MedicineSourceValidationMetadata

    public init(
        sourceIdentifier: String,
        records: [MedicineKnowledgeRecord],
        sourceReference: SourceReference,
        sourceDocumentVersion: String,
        fetchedAt: Date,
        completeness: Double,
        validationStatus: MedicineKnowledgeValidationStatus,
        validationMetadata: MedicineSourceValidationMetadata
    ) {
        self.sourceIdentifier = sourceIdentifier
        self.records = records
        self.sourceReference = sourceReference
        self.sourceDocumentVersion = sourceDocumentVersion
        self.fetchedAt = fetchedAt
        self.completeness = completeness
        self.validationStatus = validationStatus
        self.validationMetadata = validationMetadata
    }
}

public struct MedicineSourceConflict:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let medicineIdentifier: String
    public let field: String
    public let preferredSourceIdentifier: String
    public let conflictingSourceIdentifier: String
    public let preferredValue: String
    public let conflictingValue: String

    public init(
        medicineIdentifier: String,
        field: String,
        preferredSourceIdentifier: String,
        conflictingSourceIdentifier: String,
        preferredValue: String,
        conflictingValue: String
    ) {
        self.medicineIdentifier = medicineIdentifier
        self.field = field
        self.preferredSourceIdentifier = preferredSourceIdentifier
        self.conflictingSourceIdentifier = conflictingSourceIdentifier
        self.preferredValue = preferredValue
        self.conflictingValue = conflictingValue
    }
}

public struct MedicineKnowledgeCandidate:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let medicine: Medicine
    public let completeness: Double
    public let validationStatus: MedicineKnowledgeValidationStatus
    public let sourceIdentifiers: [String]
    public let conflicts: [MedicineSourceConflict]
    public let warnings: [MedicineKnowledgeWarning]
    public let requiresConfirmation: Bool

    public init(
        medicine: Medicine,
        completeness: Double,
        validationStatus: MedicineKnowledgeValidationStatus,
        sourceIdentifiers: [String],
        conflicts: [MedicineSourceConflict],
        warnings: [MedicineKnowledgeWarning],
        requiresConfirmation: Bool
    ) {
        self.medicine = medicine
        self.completeness = completeness
        self.validationStatus = validationStatus
        self.sourceIdentifiers = sourceIdentifiers
        self.conflicts = conflicts
        self.warnings = warnings
        self.requiresConfirmation = requiresConfirmation
    }
}

public struct MedicineKnowledgeSearchResult:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
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

    public var sourceDataVersion: String {
        sourceVersions
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }

    public var requiresConservativeAction: Bool {
        isOffline
            || sourceStatus == .partial
            || sourceStatus == .conflicting
            || sourceStatus == .staleOffline
            || candidates.contains(where: \.requiresConfirmation)
    }

    public init(
        normalizedQuery: String,
        candidates: [MedicineKnowledgeCandidate],
        sourceStatus: MedicineKnowledgeSourceStatus,
        cacheStatus: MedicineKnowledgeCacheStatus,
        completeness: Double,
        sourceReferences: [SourceReference],
        warnings: [MedicineKnowledgeWarning],
        sourceVersions: [String: String],
        generatedAt: Date,
        isOffline: Bool
    ) {
        self.normalizedQuery = normalizedQuery
        self.candidates = candidates
        self.sourceStatus = sourceStatus
        self.cacheStatus = cacheStatus
        self.completeness = completeness
        self.sourceReferences = sourceReferences
        self.warnings = warnings
        self.sourceVersions = sourceVersions
        self.generatedAt = generatedAt
        self.isOffline = isOffline
    }
}

public enum MedicineKnowledgeError: Error, Sendable, Equatable {
    case knowledgeSourceUnavailable(sourceIdentifier: String?)
    case knowledgeSourceTimeout(sourceIdentifier: String?)
    case invalidSourceResponse(sourceIdentifier: String?)
    case sourceVersionUnsupported(
        sourceIdentifier: String,
        version: String
    )
    case medicineNotFound
    case sourceConflict
    case offlineCacheUnavailable
    case malformedRequest
    case requestCancelled
}
