import SlowWalkDomain

/// Blocks medicine-specific guidance until the medicine identity is confirmed.
public struct RecognitionFailureRule: MedicationRiskRule {
    public let identifier = "recognition-failure"

    public init() {}

    public func evaluate(context: MedicationRiskContext) -> RiskFinding? {
        let recognizedText = RuleSupport.normalized(context.scanEvent.recognizedText)
        let candidateID = context.scanEvent.candidateMedicineID.map(RuleSupport.normalized)
        let expectedID = RuleSupport.normalized(context.medicine.id)

        let isConfirmed = context.scanEvent.recognitionStatus == .recognized
            && !recognizedText.isEmpty
            && candidateID == expectedID

        guard !isConfirmed else {
            return nil
        }

        return RiskFinding(
            level: .yellow,
            reason: RiskReason(
                code: .recognitionFailed,
                message: "The medicine identity could not be reliably confirmed.",
                evidence: "Recognition status: \(context.scanEvent.recognitionStatus.rawValue).",
                ruleIdentifier: identifier
            ),
            recommendedActions: [
                .doNotTakeUntilMedicineConfirmed,
                .retakeMedicinePhoto,
                .consultHealthcareProfessional,
            ],
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: false,
            evidenceCompleteness: .insufficient
        )
    }
}
