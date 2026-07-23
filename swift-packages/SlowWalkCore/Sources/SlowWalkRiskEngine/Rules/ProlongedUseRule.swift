import Foundation
import SlowWalkDomain

/// Demo-only duration rule based on a sequence of matching history records.
public struct ProlongedUseRule: MedicationRiskRule {
    public let identifier = "prolonged-use"

    private let yellowThreshold: TimeInterval
    private let orangeThreshold: TimeInterval
    private let maximumGap: TimeInterval
    private let futureTimestampTolerance: TimeInterval

    public init(configuration: MedicationRiskConfiguration) {
        yellowThreshold = configuration.prolongedUseYellowThreshold
        orangeThreshold = configuration.prolongedUseOrangeThreshold
        maximumGap = configuration.prolongedUseMaximumGap
        futureTimestampTolerance = configuration.futureTimestampTolerance
    }

    public func evaluate(context: MedicationRiskContext) -> RiskFinding? {
        let upperBound = context.assessedAt.addingTimeInterval(futureTimestampTolerance)
        let dates = RuleSupport.matchingRecords(
            in: context,
            noLaterThan: upperBound
        )
        .map(\.recordedAt)
        .sorted()

        guard let firstDate = dates.first else {
            return nil
        }

        var sequenceStart = firstDate
        var previousDate = firstDate
        var longestDuration: TimeInterval = 0

        for date in dates.dropFirst() {
            if date.timeIntervalSince(previousDate) <= maximumGap {
                longestDuration = max(
                    longestDuration,
                    date.timeIntervalSince(sequenceStart)
                )
            } else {
                sequenceStart = date
            }
            previousDate = date
        }

        let level: RiskLevel
        if longestDuration >= orangeThreshold {
            level = .orange
        } else if longestDuration >= yellowThreshold {
            level = .yellow
        } else {
            return nil
        }

        return RiskFinding(
            level: level,
            reason: RiskReason(
                code: .prolongedUse,
                message: "A matching record sequence exceeded a configured demo duration.",
                evidence: "Longest observed sequence: \(Int(longestDuration)) seconds.",
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
