import Foundation
import SlowWalkClientCore

/// Why a simulated medicine read could not produce a usable name.
enum MedicineReadSetback: Equatable, Hashable, CaseIterable {
    case textNotLegible
    case noMedicineNameFound
}

struct MedicineReadAttempt: Equatable, Hashable {
    let attemptNumber: Int
    let setback: MedicineReadSetback?

    static let first = MedicineReadAttempt(attemptNumber: 1, setback: nil)

    var isAwaitingRecovery: Bool { setback != nil }

    func retried() -> MedicineReadAttempt {
        MedicineReadAttempt(attemptNumber: attemptNumber + 1, setback: nil)
    }

    func interrupted(by setback: MedicineReadSetback) -> MedicineReadAttempt {
        MedicineReadAttempt(attemptNumber: attemptNumber, setback: setback)
    }
}

enum MedicineChoiceOrigin: Equatable, Hashable {
    case readFromPhoto
    case chosenFromFrequentList
}

/// A non-clinical medicine-name option produced by the scripted read step.
struct MedicineCandidate: Equatable, Hashable, Identifiable {
    let id: String
    let displayName: String
    let recognitionHint: String
}

struct MedicineConfirmationPrompt: Equatable, Hashable {
    let candidates: [MedicineCandidate]
    let origin: MedicineChoiceOrigin
    let attemptNumber: Int
}

struct ConfirmedMedicine: Equatable, Hashable {
    let candidate: MedicineCandidate
    let origin: MedicineChoiceOrigin
}

/// The assessment step keeps the canonical Client Core state verbatim.
///
/// It deliberately defines no app-owned risk, warning, or result enum. The
/// presentation package maps `viewState`, and departure is possible only when
/// the value is the canonical `.result` case.
struct MedicineAssessmentGate: Equatable {
    let confirmed: ConfirmedMedicine
    let prompt: MedicineConfirmationPrompt
    let viewState: MedicineAssessmentViewState

    var hasFinalResult: Bool {
        if case .result = viewState { return true }
        return false
    }

    func updating(
        viewState: MedicineAssessmentViewState
    ) -> MedicineAssessmentGate {
        MedicineAssessmentGate(
            confirmed: confirmed,
            prompt: prompt,
            viewState: viewState
        )
    }
}

enum CompanionCompletion: Equatable, Hashable {
    case arrivedSafely
    case medicineReviewCompleted
    case endedEarly
}

enum CompanionFlowState: Equatable {
    case notStarted
    case preDepartureCheck
    case scanningMedicine(MedicineReadAttempt)
    case awaitingMedicineConfirmation(MedicineConfirmationPrompt)
    case awaitingMedicineAssessment(MedicineAssessmentGate)
    case travelling
    case approachingStop
    case completed(CompanionCompletion)

    var isActive: Bool {
        switch self {
        case .notStarted, .completed:
            false
        case .preDepartureCheck,
            .scanningMedicine,
            .awaitingMedicineConfirmation,
            .awaitingMedicineAssessment,
            .travelling,
            .approachingStop:
            true
        }
    }
}

enum CompanionFlowEvent: Equatable {
    case startCompanion
    case beginMedicineRead
    case medicineReadDidNotSucceed(MedicineReadSetback)
    case retryMedicineRead
    case chooseFromFrequentList([MedicineCandidate])
    case medicineCandidatesReady([MedicineCandidate])
    case retakeMedicinePhoto
    case confirmMedicine(MedicineCandidate)
    case medicineAssessmentUpdated(MedicineAssessmentViewState)
    case reconsiderMedicineChoice
    case continueAfterMedicineAssessment(hasOuting: Bool)
    case approachStop
    case arriveSafely
    case endEarly
}
