import Foundation
import SlowWalkClientCore

/// A one-line summary of where the current companion session stands.
///
/// Today uses this so the app can pick up where the person left off instead of
/// starting over.
struct TodayStatusSummary: Equatable, Hashable {
    let stepLabel: String
    let situation: String
    let nextStep: String
    let isSessionUnderway: Bool
    let hasFinishedSession: Bool

    init(
        state: CompanionFlowState,
        medicineState: MedicineAssessmentViewState,
        capabilities: CapabilityCatalog
    ) {
        stepLabel = CompanionCopy.stepLabel(
            for: state,
            medicineState: medicineState
        )
        situation = CompanionCopy.situation(
            for: state,
            medicineState: medicineState,
            capabilities: capabilities
        )
        nextStep = CompanionCopy.nextStep(
            for: state,
            medicineState: medicineState
        )
        isSessionUnderway = state.isActive
        if case .completed = state {
            hasFinishedSession = true
        } else {
            hasFinishedSession = false
        }
    }

    /// Title for Today's primary action, which continues an existing session
    /// rather than silently restarting it.
    var primaryActionTitle: String {
        isSessionUnderway
            ? CompanionCopy.continueCompanionTitle
            : CompanionCopy.startCompanionTitle
    }

    var accessibilityLabel: String {
        "当前陪伴状态：\(stepLabel)。\(situation)\(nextStep)"
    }
}
