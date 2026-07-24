import SlowWalkDomain

/// Preserves preflight data-quality warnings in deterministic risk output.
public struct HealthContextValidationRule: MedicationRiskRule {
    public let identifier = "health-context-validation"

    public init() {}

    public func evaluate(
        context: MedicationRiskContext
    ) -> RiskFinding? {
        guard !context.healthContextWarnings.isEmpty else {
            return nil
        }
        let codes = context.healthContextWarnings
            .map(\.code)
            .sorted()
        var actions: [RecommendedAction] = [
            .consultHealthcareProfessional,
        ]
        if codes.contains(where: { $0.contains("BODY_METRICS") }) {
            actions.append(.remeasureBodyMetrics)
        }
        if codes.contains(where: { $0.contains("HISTORY")
            || $0.contains("MEDICATION_RECORD") }) {
            actions.append(.reviewMedicationHistory)
        }
        if codes.contains(where: { $0.contains("PROFILE") }) {
            actions.append(.updateHealthProfile)
        }
        if codes.contains(where: { $0.contains("SOURCE") }) {
            actions.append(.reviewMedicineSources)
        }

        return RiskFinding(
            level: .yellow,
            reason: RiskReason(
                code: .healthContextWarning,
                message: "Health-context data-quality warnings require review.",
                evidence: "Validation codes: \(codes.joined(separator: ", ")).",
                ruleIdentifier: identifier
            ),
            recommendedActions: Array(Set(actions)).sorted {
                $0.rawValue < $1.rawValue
            },
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: false,
            evidenceCompleteness: min(
                context.evidenceCompleteness,
                .partial
            )
        )
    }
}
