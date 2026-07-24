import Foundation
import SlowWalkDomain

/// Creates a single cross-platform action card without UI framework types.
public struct ActionCardFactory: Sendable {
    public init() {}

    public func makeCard(
        resolution: MedicineResolution,
        assessment: RiskAssessment?,
        generatedAt: Date,
        healthContextWarnings: [HealthContextValidationIssue] = []
    ) -> ActionCard {
        guard resolution.status == .resolved,
              let medicine = resolution.selectedMedicine,
              let assessment else {
            return confirmationCard(
                resolution: resolution,
                generatedAt: generatedAt,
                healthContextWarnings: healthContextWarnings
            )
        }

        let hasCompleteEvidence =
            assessment.evidenceCompleteness == .complete
        let effectiveLevel = hasCompleteEvidence
            ? assessment.level
            : max(.yellow, assessment.level)
        var actions = assessment.recommendedActions
        if assessment.level == .red {
            actions.removeAll {
                $0 == .followVerifiedSourceInformation
            }
        }
        if !hasCompleteEvidence {
            actions.removeAll {
                $0 == .followVerifiedSourceInformation
            }
            actions.append(.reviewMedicineSources)
            actions.append(.consultHealthcareProfessional)
        }

        return ActionCard(
            title: medicine.canonicalName,
            primaryInstruction: primaryInstruction(
                for: effectiveLevel
            ),
            warnings: unique(
                medicine.warnings
                    + healthContextWarnings.map(\.message)
                    + assessment.reasons.map(\.message)
            ),
            recommendedActions: stableActions(actions),
            riskLevel: effectiveLevel,
            sourceReferences: medicine.sourceReferences,
            mustConfirmMedicine: false,
            generatedAt: generatedAt
        )
    }

    private func confirmationCard(
        resolution: MedicineResolution,
        generatedAt: Date,
        healthContextWarnings: [HealthContextValidationIssue]
    ) -> ActionCard {
        ActionCard(
            title: "Unable to confirm the medicine",
            primaryInstruction:
                "Retake a clear photo of the front of the medicine box.",
            warnings: [
                "Do not take this medicine until its identity is confirmed.",
                resolutionWarning(for: resolution.status),
            ] + healthContextWarnings.map(\.message),
            recommendedActions: stableActions([
                .doNotTakeUntilMedicineConfirmed,
                .retakeMedicinePhoto,
                .consultHealthcareProfessional,
            ]),
            riskLevel: .yellow,
            sourceReferences: [],
            mustConfirmMedicine: true,
            generatedAt: generatedAt
        )
    }

    private func primaryInstruction(for level: RiskLevel) -> String {
        switch level {
        case .green:
            return "Review the verified source information before use."
        case .yellow:
            return "Pause and review the available information."
        case .orange:
            return "Review the medication history with a healthcare professional."
        case .red:
            return "Do not take this medicine until a healthcare professional confirms the next step."
        }
    }

    private func resolutionWarning(
        for status: MedicineResolutionStatus
    ) -> String {
        switch status {
        case .resolved:
            return "A risk assessment is not available for the resolved medicine."
        case .ambiguous:
            return "More than one medicine matched the recognized text."
        case .insufficientEvidence:
            return "The available recognition evidence is insufficient."
        case .notFound:
            return "No medicine in the verified data matched the recognized text."
        case .recognitionFailed:
            return "The medicine text could not be recognized reliably."
        }
    }

    private func stableActions(
        _ actions: [RecommendedAction]
    ) -> [RecommendedAction] {
        let priority: [RecommendedAction: Int] = [
            .doNotTakeUntilMedicineConfirmed: 0,
            .retakeMedicinePhoto: 1,
            .consultHealthcareProfessional: 2,
            .notifyFamilyMember: 3,
            .reviewMedicineSources: 4,
            .updateHealthProfile: 5,
            .remeasureBodyMetrics: 6,
            .reviewMedicationHistory: 7,
            .followVerifiedSourceInformation: 8,
        ]
        return Array(Set(actions)).sorted {
            let left = priority[$0, default: .max]
            let right = priority[$1, default: .max]
            if left != right {
                return left < right
            }
            return $0.rawValue < $1.rawValue
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
