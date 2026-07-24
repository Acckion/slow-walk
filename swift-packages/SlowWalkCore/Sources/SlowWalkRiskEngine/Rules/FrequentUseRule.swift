import Foundation
import SlowWalkDomain

/// Demo-only frequency rule using an injected rolling-window configuration.
public struct FrequentUseRule: MedicationRiskRule {
    public let identifier = "frequent-use"

    private let lookbackWindow: TimeInterval
    private let threshold: Int
    private let futureTimestampTolerance: TimeInterval

    public init(configuration: MedicationRiskConfiguration) {
        lookbackWindow = configuration.recentUseWindow
        threshold = configuration.frequentUseThreshold
        futureTimestampTolerance = configuration.futureTimestampTolerance
    }

    public func evaluate(context: MedicationRiskContext) -> RiskFinding? {
        let lowerBound = context.assessedAt.addingTimeInterval(-lookbackWindow)
        let upperBound = context.assessedAt.addingTimeInterval(futureTimestampTolerance)
        let matchingRecords = RuleSupport.matchingRecords(
            in: context,
            noEarlierThan: lowerBound,
            noLaterThan: upperBound
        )

        guard matchingRecords.count >= threshold else {
            return nil
        }

        return RiskFinding(
            level: .orange,
            reason: RiskReason(
                code: .frequentUse,
                message: "Recent matching records reached the configured demo threshold.",
                evidence: "Unique matching records: \(matchingRecords.count); demo threshold: \(threshold).",
                ruleIdentifier: identifier
            ),
            recommendedActions: [
                .reviewMedicationHistory,
                .consultHealthcareProfessional,
            ],
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: false,
            evidenceCompleteness: context.evidenceCompleteness
        )
    }
}
