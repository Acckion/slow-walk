import Foundation

/// Stable machine-readable reason codes. Raw values are part of API v1.
public enum RiskReasonCode: String, Codable, Sendable, CaseIterable, Hashable {
    case allergyMatch = "allergy_match"
    case duplicateActiveIngredient = "duplicate_active_ingredient"
    case frequentUse = "frequent_use"
    case prolongedUse = "prolonged_use"
    case missingEvidence = "missing_evidence"
    case recognitionFailed = "recognition_failed"
    case bodyMetricsMissing = "body_metrics_missing"
    case bodyMetricsStale = "body_metrics_stale"
    case bodyMetricsInvalid = "body_metrics_invalid"
}

/// A traceable explanation produced by one deterministic risk rule.
public struct RiskReason: Codable, Sendable, Equatable, Hashable {
    public let code: RiskReasonCode
    public let message: String
    public let evidence: String
    public let ruleIdentifier: String

    public init(
        code: RiskReasonCode,
        message: String,
        evidence: String,
        ruleIdentifier: String
    ) {
        self.code = code
        self.message = message
        self.evidence = evidence
        self.ruleIdentifier = ruleIdentifier
    }
}

/// Safe, non-diagnostic actions that can be rendered by a client.
public enum RecommendedAction: String, Codable, Sendable, CaseIterable, Hashable {
    case followVerifiedSourceInformation = "follow_verified_source_information"
    case consultHealthcareProfessional = "consult_healthcare_professional"
    case notifyFamilyMember = "notify_family_member"
    case reviewMedicineSources = "review_medicine_sources"
    case updateHealthProfile = "update_health_profile"
    case retakeMedicinePhoto = "retake_medicine_photo"
    case doNotTakeUntilMedicineConfirmed = "do_not_take_until_medicine_confirmed"
    case reviewMedicationHistory = "review_medication_history"
    case remeasureBodyMetrics = "remeasure_body_metrics"
}

/// Completeness of the evidence available to the rules.
public enum EvidenceCompleteness: String, Codable, Sendable, CaseIterable, Hashable, Comparable {
    case insufficient
    case partial
    case complete

    public static func < (lhs: EvidenceCompleteness, rhs: EvidenceCompleteness) -> Bool {
        lhs.completenessRank < rhs.completenessRank
    }

    private var completenessRank: Int {
        switch self {
        case .insufficient:
            0
        case .partial:
            1
        case .complete:
            2
        }
    }
}

/// Explainable result of a medication risk reminder assessment.
///
/// This model is not a diagnosis or treatment plan.
public struct RiskAssessment: Codable, Sendable, Equatable, Hashable {
    public let level: RiskLevel
    public let reasons: [RiskReason]
    public let recommendedActions: [RecommendedAction]
    public let assessedAt: Date
    public let requiresProfessionalAdvice: Bool
    public let requiresFamilyAttention: Bool
    public let evidenceCompleteness: EvidenceCompleteness

    public init(
        level: RiskLevel,
        reasons: [RiskReason],
        recommendedActions: [RecommendedAction],
        assessedAt: Date,
        requiresProfessionalAdvice: Bool,
        requiresFamilyAttention: Bool,
        evidenceCompleteness: EvidenceCompleteness
    ) {
        self.level = level
        self.reasons = reasons
        self.recommendedActions = recommendedActions
        self.assessedAt = assessedAt
        self.requiresProfessionalAdvice = requiresProfessionalAdvice
        self.requiresFamilyAttention = requiresFamilyAttention
        self.evidenceCompleteness = evidenceCompleteness
    }
}
