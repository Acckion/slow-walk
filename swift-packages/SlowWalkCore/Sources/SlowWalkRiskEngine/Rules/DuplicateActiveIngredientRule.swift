import SlowWalkDomain

/// Raises a red reminder for active ingredients already present in the profile.
public struct DuplicateActiveIngredientRule: MedicationRiskRule {
    public let identifier = "duplicate-active-ingredient"

    public init() {}

    public func evaluate(context: MedicationRiskContext) -> RiskFinding? {
        let currentIngredients = RuleSupport.normalizedSet(
            context.userProfile.currentMedicineIngredientIDs
        )
        let candidateIngredients = RuleSupport.normalizedSet(
            context.medicine.activeIngredientIDs
        )
        let duplicates = currentIngredients.intersection(candidateIngredients).sorted()

        guard !duplicates.isEmpty else {
            return nil
        }

        return RiskFinding(
            level: .red,
            reason: RiskReason(
                code: .duplicateActiveIngredient,
                message: "An active ingredient is already present in the medication profile.",
                evidence: "Matched ingredient identifiers: \(duplicates.joined(separator: ", ")).",
                ruleIdentifier: identifier
            ),
            recommendedActions: [
                .doNotTakeUntilMedicineConfirmed,
                .consultHealthcareProfessional,
                .reviewMedicationHistory,
                .notifyFamilyMember,
            ],
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: true,
            evidenceCompleteness: context.evidenceCompleteness
        )
    }
}
