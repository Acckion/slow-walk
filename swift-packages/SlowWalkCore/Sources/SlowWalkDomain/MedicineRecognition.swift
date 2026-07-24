import Foundation

/// Simulated OCR output supplied to the cross-platform medicine pipeline.
///
/// Image bytes are deliberately excluded. Real camera and Vision integration
/// remain outside SlowWalkCore.
public struct MedicineRecognitionInput: Codable, Sendable, Equatable, Hashable {
    public let recognizedTexts: [String]
    public let capturedAt: Date
    public let languageCode: String?
    public let rawConfidence: Double?

    public init(
        recognizedTexts: [String],
        capturedAt: Date,
        languageCode: String?,
        rawConfidence: Double?
    ) {
        self.recognizedTexts = recognizedTexts
        self.capturedAt = capturedAt
        self.languageCode = languageCode
        self.rawConfidence = rawConfidence
    }
}

/// Deterministic output from medicine-name normalization.
public struct NormalizedMedicineName: Codable, Sendable, Equatable, Hashable {
    public let normalizedText: String
    public let normalizedQuery: String
    public let queryVariants: [String]
    public let dosageForms: [String]
    public let removedSpecifications: [String]
    public let discardedNoise: [String]

    public init(
        normalizedText: String,
        normalizedQuery: String,
        queryVariants: [String],
        dosageForms: [String],
        removedSpecifications: [String],
        discardedNoise: [String]
    ) {
        self.normalizedText = normalizedText
        self.normalizedQuery = normalizedQuery
        self.queryVariants = queryVariants
        self.dosageForms = dosageForms
        self.removedSpecifications = removedSpecifications
        self.discardedNoise = discardedNoise
    }
}

/// Stable reasons explaining why a candidate received its match score.
public enum MedicineMatchReason: String, Codable, Sendable, CaseIterable, Hashable {
    case canonicalExact = "canonical_exact"
    case aliasExact = "alias_exact"
    case canonicalNormalized = "canonical_normalized"
    case aliasNormalized = "alias_normalized"
    case conservativeApproximate = "conservative_approximate"
}

/// One deterministic, traceable medicine match candidate.
public struct MedicineCandidate: Codable, Sendable, Equatable, Hashable {
    public let medicine: Medicine
    public let matchScore: Double
    public let matchedAlias: String?
    public let matchReasons: [MedicineMatchReason]

    public init(
        medicine: Medicine,
        matchScore: Double,
        matchedAlias: String?,
        matchReasons: [MedicineMatchReason]
    ) {
        self.medicine = medicine
        self.matchScore = matchScore
        self.matchedAlias = matchedAlias
        self.matchReasons = matchReasons
    }
}

/// Stable resolution state shared by Core, API clients, and the server.
public enum MedicineResolutionStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case resolved
    case ambiguous
    case insufficientEvidence = "insufficient_evidence"
    case notFound = "not_found"
    case recognitionFailed = "recognition_failed"
}

/// Evidence retained with a resolution so that decisions are auditable.
public struct MedicineResolutionEvidence: Codable, Sendable, Equatable, Hashable {
    public let recognizedTexts: [String]
    public let normalizedText: String
    public let normalizedQuery: String
    public let languageCode: String?
    public let rawConfidence: Double?
    public let dosageForms: [String]
    public let removedSpecifications: [String]
    public let discardedNoise: [String]
    public let matcherVersion: String
    public let sourceDataVersions: [String]

    public init(
        recognizedTexts: [String],
        normalizedText: String,
        normalizedQuery: String,
        languageCode: String?,
        rawConfidence: Double?,
        dosageForms: [String],
        removedSpecifications: [String],
        discardedNoise: [String],
        matcherVersion: String,
        sourceDataVersions: [String]
    ) {
        self.recognizedTexts = recognizedTexts
        self.normalizedText = normalizedText
        self.normalizedQuery = normalizedQuery
        self.languageCode = languageCode
        self.rawConfidence = rawConfidence
        self.dosageForms = dosageForms
        self.removedSpecifications = removedSpecifications
        self.discardedNoise = discardedNoise
        self.matcherVersion = matcherVersion
        self.sourceDataVersions = sourceDataVersions
    }
}

/// Resolution result. A selected medicine is present only when evidence permits
/// deterministic selection.
public struct MedicineResolution: Codable, Sendable, Equatable, Hashable {
    public let status: MedicineResolutionStatus
    public let candidates: [MedicineCandidate]
    public let selectedMedicine: Medicine?
    public let evidence: MedicineResolutionEvidence
    public let requiresUserConfirmation: Bool

    public init(
        status: MedicineResolutionStatus,
        candidates: [MedicineCandidate],
        selectedMedicine: Medicine?,
        evidence: MedicineResolutionEvidence,
        requiresUserConfirmation: Bool
    ) {
        self.status = status
        self.candidates = candidates
        self.selectedMedicine = selectedMedicine
        self.evidence = evidence
        self.requiresUserConfirmation = requiresUserConfirmation
    }
}

/// Observable cache result included in pipeline and transport responses.
public enum MedicineResolutionCacheStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case hit
    case miss
    case expired
    case sourceVersionChanged = "source_version_changed"
}

/// Structured, non-diagnostic output rendered by a client.
public struct ActionCard: Codable, Sendable, Equatable, Hashable {
    public let title: String
    public let primaryInstruction: String
    public let warnings: [String]
    public let recommendedActions: [RecommendedAction]
    public let riskLevel: RiskLevel
    public let sourceReferences: [SourceReference]
    public let mustConfirmMedicine: Bool
    public let generatedAt: Date

    public init(
        title: String,
        primaryInstruction: String,
        warnings: [String],
        recommendedActions: [RecommendedAction],
        riskLevel: RiskLevel,
        sourceReferences: [SourceReference],
        mustConfirmMedicine: Bool,
        generatedAt: Date
    ) {
        self.title = title
        self.primaryInstruction = primaryInstruction
        self.warnings = warnings
        self.recommendedActions = recommendedActions
        self.riskLevel = riskLevel
        self.sourceReferences = sourceReferences
        self.mustConfirmMedicine = mustConfirmMedicine
        self.generatedAt = generatedAt
    }
}
