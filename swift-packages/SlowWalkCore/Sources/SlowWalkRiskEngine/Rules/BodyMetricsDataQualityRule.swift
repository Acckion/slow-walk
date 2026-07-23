import Foundation
import SlowWalkDomain

/// Checks only presence, recency, and structural plausibility of body metrics.
///
/// It deliberately contains no clinical diagnostic thresholds.
public struct BodyMetricsDataQualityRule: MedicationRiskRule {
    public let identifier = "body-metrics-data-quality"

    private let maximumAge: TimeInterval
    private let futureTimestampTolerance: TimeInterval

    public init(configuration: MedicationRiskConfiguration) {
        maximumAge = configuration.bodyMetricsMaximumAge
        futureTimestampTolerance = configuration.futureTimestampTolerance
    }

    public func evaluate(context: MedicationRiskContext) -> RiskFinding? {
        guard let metrics = context.userProfile.bodyMetrics else {
            return finding(
                code: .bodyMetricsMissing,
                message: "Body metrics are unavailable for this assessment.",
                evidence: "No body-metrics record was supplied.",
                completeness: min(context.evidenceCompleteness, .partial)
            )
        }

        let hasAnyMeasurement = metrics.systolicBloodPressure != nil
            || metrics.diastolicBloodPressure != nil
            || metrics.heartRate != nil
        let hasIncompletePressurePair =
            (metrics.systolicBloodPressure == nil) != (metrics.diastolicBloodPressure == nil)
        let hasNonPositiveValue = [
            metrics.systolicBloodPressure,
            metrics.diastolicBloodPressure,
            metrics.heartRate,
        ]
        .compactMap { $0 }
        .contains(where: { $0 <= 0 })

        guard hasAnyMeasurement,
              !hasIncompletePressurePair,
              !hasNonPositiveValue,
              let measuredAt = metrics.measuredAt
        else {
            return finding(
                code: .bodyMetricsInvalid,
                message: "Body metrics are incomplete or structurally invalid.",
                evidence: "Only presence, pairing, timestamp, and positive numeric format were checked.",
                completeness: min(context.evidenceCompleteness, .partial)
            )
        }

        let latestAcceptedDate = context.assessedAt.addingTimeInterval(
            futureTimestampTolerance
        )
        if measuredAt > latestAcceptedDate {
            return finding(
                code: .bodyMetricsInvalid,
                message: "The body-metrics timestamp is in the future.",
                evidence: "Measured-at is later than the assessment reference time.",
                completeness: min(context.evidenceCompleteness, .partial)
            )
        }

        if context.assessedAt.timeIntervalSince(measuredAt) > maximumAge {
            return finding(
                code: .bodyMetricsStale,
                message: "Body metrics are older than the configured demo age limit.",
                evidence: "The rule checks recency only and applies no diagnostic threshold.",
                completeness: min(context.evidenceCompleteness, .partial)
            )
        }

        return nil
    }

    private func finding(
        code: RiskReasonCode,
        message: String,
        evidence: String,
        completeness: EvidenceCompleteness
    ) -> RiskFinding {
        RiskFinding(
            level: .yellow,
            reason: RiskReason(
                code: code,
                message: message,
                evidence: evidence,
                ruleIdentifier: identifier
            ),
            recommendedActions: [
                .remeasureBodyMetrics,
                .consultHealthcareProfessional,
            ],
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: false,
            evidenceCompleteness: completeness
        )
    }
}
