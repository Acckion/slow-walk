import Foundation

/// Invalid demo configuration supplied by a caller.
public enum MedicationRiskConfigurationError: Error, Sendable, Equatable {
    case nonPositiveDuration(field: String)
    case nonPositiveCount(field: String)
    case invalidRecognitionConfidence
    case orangeThresholdBelowYellowThreshold
    case negativeFutureTimestampTolerance
}

/// Centralized thresholds for demonstration rules.
///
/// These defaults are product-demo settings and are not clinical standards.
public struct MedicationRiskConfiguration: Sendable, Equatable, Hashable {
    public let recentUseWindow: TimeInterval
    public let frequentUseThreshold: Int
    public let prolongedUseYellowThreshold: TimeInterval
    public let prolongedUseOrangeThreshold: TimeInterval
    public let prolongedUseMaximumGap: TimeInterval
    public let minimumRecognitionConfidence: Double
    public let bodyMetricsMaximumAge: TimeInterval
    public let futureTimestampTolerance: TimeInterval

    public init(
        recentUseWindow: TimeInterval,
        frequentUseThreshold: Int,
        prolongedUseYellowThreshold: TimeInterval,
        prolongedUseOrangeThreshold: TimeInterval,
        prolongedUseMaximumGap: TimeInterval,
        minimumRecognitionConfidence: Double,
        bodyMetricsMaximumAge: TimeInterval,
        futureTimestampTolerance: TimeInterval
    ) throws {
        guard recentUseWindow > 0 else {
            throw MedicationRiskConfigurationError.nonPositiveDuration(field: "recentUseWindow")
        }
        guard frequentUseThreshold > 0 else {
            throw MedicationRiskConfigurationError.nonPositiveCount(field: "frequentUseThreshold")
        }
        guard prolongedUseYellowThreshold > 0 else {
            throw MedicationRiskConfigurationError.nonPositiveDuration(
                field: "prolongedUseYellowThreshold"
            )
        }
        guard prolongedUseOrangeThreshold > 0 else {
            throw MedicationRiskConfigurationError.nonPositiveDuration(
                field: "prolongedUseOrangeThreshold"
            )
        }
        guard prolongedUseMaximumGap > 0 else {
            throw MedicationRiskConfigurationError.nonPositiveDuration(
                field: "prolongedUseMaximumGap"
            )
        }
        guard prolongedUseOrangeThreshold >= prolongedUseYellowThreshold else {
            throw MedicationRiskConfigurationError.orangeThresholdBelowYellowThreshold
        }
        guard (0.0 ... 1.0).contains(minimumRecognitionConfidence) else {
            throw MedicationRiskConfigurationError.invalidRecognitionConfidence
        }
        guard bodyMetricsMaximumAge > 0 else {
            throw MedicationRiskConfigurationError.nonPositiveDuration(
                field: "bodyMetricsMaximumAge"
            )
        }
        guard futureTimestampTolerance >= 0 else {
            throw MedicationRiskConfigurationError.negativeFutureTimestampTolerance
        }

        self.init(
            validatedRecentUseWindow: recentUseWindow,
            frequentUseThreshold: frequentUseThreshold,
            prolongedUseYellowThreshold: prolongedUseYellowThreshold,
            prolongedUseOrangeThreshold: prolongedUseOrangeThreshold,
            prolongedUseMaximumGap: prolongedUseMaximumGap,
            minimumRecognitionConfidence: minimumRecognitionConfidence,
            bodyMetricsMaximumAge: bodyMetricsMaximumAge,
            futureTimestampTolerance: futureTimestampTolerance
        )
    }

    /// Default competition-demo configuration; not for clinical use.
    public static let demo = MedicationRiskConfiguration(
        validatedRecentUseWindow: 7 * 24 * 60 * 60,
        frequentUseThreshold: 3,
        prolongedUseYellowThreshold: 3 * 24 * 60 * 60,
        prolongedUseOrangeThreshold: 7 * 24 * 60 * 60,
        prolongedUseMaximumGap: 2 * 24 * 60 * 60,
        minimumRecognitionConfidence: 0.75,
        bodyMetricsMaximumAge: 30 * 24 * 60 * 60,
        futureTimestampTolerance: 0
    )

    private init(
        validatedRecentUseWindow: TimeInterval,
        frequentUseThreshold: Int,
        prolongedUseYellowThreshold: TimeInterval,
        prolongedUseOrangeThreshold: TimeInterval,
        prolongedUseMaximumGap: TimeInterval,
        minimumRecognitionConfidence: Double,
        bodyMetricsMaximumAge: TimeInterval,
        futureTimestampTolerance: TimeInterval
    ) {
        recentUseWindow = validatedRecentUseWindow
        self.frequentUseThreshold = frequentUseThreshold
        self.prolongedUseYellowThreshold = prolongedUseYellowThreshold
        self.prolongedUseOrangeThreshold = prolongedUseOrangeThreshold
        self.prolongedUseMaximumGap = prolongedUseMaximumGap
        self.minimumRecognitionConfidence = minimumRecognitionConfidence
        self.bodyMetricsMaximumAge = bodyMetricsMaximumAge
        self.futureTimestampTolerance = futureTimestampTolerance
    }
}
