import Foundation
import SlowWalkDomain

/// Prevents a green result when sources, recognition, profile, or timestamps are incomplete.
public struct MissingEvidenceRule: MedicationRiskRule {
    public let identifier = "missing-evidence"

    private let minimumRecognitionConfidence: Double
    private let futureTimestampTolerance: TimeInterval

    public init(configuration: MedicationRiskConfiguration) {
        minimumRecognitionConfidence = configuration.minimumRecognitionConfidence
        futureTimestampTolerance = configuration.futureTimestampTolerance
    }

    public func evaluate(context: MedicationRiskContext) -> RiskFinding? {
        var issues = [String]()
        var actions = Set<RecommendedAction>()
        var completeness = context.evidenceCompleteness
        let latestAcceptedDate = context.assessedAt.addingTimeInterval(
            futureTimestampTolerance
        )

        if context.evidenceCompleteness != .complete {
            issues.append("Caller marked evidence as \(context.evidenceCompleteness.rawValue).")
        }
        if context.medicine.sourceReferences.isEmpty {
            issues.append("Medicine source references are missing.")
            actions.insert(.reviewMedicineSources)
            completeness = .insufficient
        }
        if context.userProfile.age <= 0 {
            issues.append("The health profile age is not a positive value.")
            actions.insert(.updateHealthProfile)
            completeness = .insufficient
        }
        if context.userProfile.updatedAt > latestAcceptedDate {
            issues.append("The health profile update time is in the future.")
            actions.insert(.updateHealthProfile)
            completeness = min(completeness, .partial)
        }
        if !(0.0 ... 1.0).contains(context.scanEvent.confidence)
            || context.scanEvent.confidence < minimumRecognitionConfidence {
            issues.append("Recognition confidence is below the configured demo minimum.")
            actions.insert(.retakeMedicinePhoto)
            completeness = min(completeness, .partial)
        }
        if context.scanEvent.scannedAt > latestAcceptedDate {
            issues.append("The scan timestamp is in the future.")
            actions.insert(.retakeMedicinePhoto)
            completeness = min(completeness, .partial)
        }
        if context.recentRecords.contains(where: { $0.recordedAt > latestAcceptedDate }) {
            issues.append("Medication history contains a future timestamp.")
            actions.insert(.reviewMedicationHistory)
            completeness = min(completeness, .partial)
        }

        guard !issues.isEmpty else {
            return nil
        }

        actions.insert(.consultHealthcareProfessional)
        return RiskFinding(
            level: .yellow,
            reason: RiskReason(
                code: .missingEvidence,
                message: "Available information is incomplete or internally inconsistent.",
                evidence: issues.sorted().joined(separator: " "),
                ruleIdentifier: identifier
            ),
            recommendedActions: actions.sorted { $0.rawValue < $1.rawValue },
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: false,
            evidenceCompleteness: completeness
        )
    }
}
