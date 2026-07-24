import SlowWalkDomain

/// One explainable result emitted by a medication-risk rule.
public struct RiskFinding: Sendable, Equatable, Hashable {
    public let level: RiskLevel
    public let reason: RiskReason
    public let recommendedActions: [RecommendedAction]
    public let requiresProfessionalAdvice: Bool
    public let requiresFamilyAttention: Bool
    public let evidenceCompleteness: EvidenceCompleteness

    public init(
        level: RiskLevel,
        reason: RiskReason,
        recommendedActions: [RecommendedAction],
        requiresProfessionalAdvice: Bool,
        requiresFamilyAttention: Bool,
        evidenceCompleteness: EvidenceCompleteness
    ) {
        self.level = level
        self.reason = reason
        self.recommendedActions = recommendedActions
        self.requiresProfessionalAdvice = requiresProfessionalAdvice
        self.requiresFamilyAttention = requiresFamilyAttention
        self.evidenceCompleteness = evidenceCompleteness
    }
}

/// Independent deterministic rule used by `MedicationRiskEngine`.
public protocol MedicationRiskRule: Sendable {
    var identifier: String { get }
    func evaluate(context: MedicationRiskContext) -> RiskFinding?
}

/// Cross-platform risk-assessment boundary.
public protocol RiskAssessing: Sendable {
    func assess(context: MedicationRiskContext) -> RiskAssessment
}
