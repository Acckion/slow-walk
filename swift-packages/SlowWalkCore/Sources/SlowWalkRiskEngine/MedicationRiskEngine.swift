import SlowWalkDomain

/// Deterministic, explainable rule aggregator.
public struct MedicationRiskEngine: RiskAssessing, Sendable {
    private let rules: [any MedicationRiskRule]

    public init(configuration: MedicationRiskConfiguration = .demo) {
        rules = [
            AllergyMatchRule(),
            DuplicateActiveIngredientRule(),
            FrequentUseRule(configuration: configuration),
            ProlongedUseRule(configuration: configuration),
            MissingEvidenceRule(configuration: configuration),
            RecognitionFailureRule(),
            BodyMetricsDataQualityRule(configuration: configuration),
        ]
    }

    public init(rules: [any MedicationRiskRule]) {
        self.rules = rules
    }

    public func assess(context: MedicationRiskContext) -> RiskAssessment {
        var findings = rules.compactMap { $0.evaluate(context: context) }

        if context.evidenceCompleteness != .complete,
           !findings.contains(where: { $0.reason.code == .missingEvidence }) {
            findings.append(Self.fallbackMissingEvidenceFinding(context: context))
        }

        findings.sort(by: Self.findingOrder)

        let level = findings.map(\.level).max() ?? .green
        let reasons = findings.map(\.reason)
        let evidenceCompleteness = findings.reduce(
            context.evidenceCompleteness
        ) { current, finding in
            min(current, finding.evidenceCompleteness)
        }

        let recommendedActions: [RecommendedAction]
        if findings.isEmpty {
            recommendedActions = [.followVerifiedSourceInformation]
        } else {
            recommendedActions = Array(
                Set(findings.flatMap(\.recommendedActions))
            )
            .sorted { $0.rawValue < $1.rawValue }
        }

        return RiskAssessment(
            level: level,
            reasons: reasons,
            recommendedActions: recommendedActions,
            assessedAt: context.assessedAt,
            requiresProfessionalAdvice: findings.contains {
                $0.requiresProfessionalAdvice
            },
            requiresFamilyAttention: findings.contains {
                $0.requiresFamilyAttention
            },
            evidenceCompleteness: evidenceCompleteness
        )
    }

    private static func fallbackMissingEvidenceFinding(
        context: MedicationRiskContext
    ) -> RiskFinding {
        RiskFinding(
            level: .yellow,
            reason: RiskReason(
                code: .missingEvidence,
                message: "Evidence is incomplete, so a green result is not permitted.",
                evidence: "Caller completeness: \(context.evidenceCompleteness.rawValue).",
                ruleIdentifier: "engine-evidence-safety-invariant"
            ),
            recommendedActions: [
                .reviewMedicineSources,
                .consultHealthcareProfessional,
            ],
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: false,
            evidenceCompleteness: context.evidenceCompleteness
        )
    }

    private static func findingOrder(_ lhs: RiskFinding, _ rhs: RiskFinding) -> Bool {
        if lhs.level != rhs.level {
            return lhs.level > rhs.level
        }
        if lhs.reason.ruleIdentifier != rhs.reason.ruleIdentifier {
            return lhs.reason.ruleIdentifier < rhs.reason.ruleIdentifier
        }
        if lhs.reason.code != rhs.reason.code {
            return lhs.reason.code.rawValue < rhs.reason.code.rawValue
        }
        if lhs.reason.evidence != rhs.reason.evidence {
            return lhs.reason.evidence < rhs.reason.evidence
        }
        return lhs.reason.message < rhs.reason.message
    }
}
