import Foundation

/// Why a medicine photo could not be read.
///
/// A setback never carries a medicine conclusion. It only describes what
/// happened so the flow can offer a recovery path instead of guessing.
enum MedicineReadSetback: Equatable, Hashable, CaseIterable {
    case textNotLegible
    case noMedicineNameFound
}

/// One medicine-reading attempt inside a single companion session.
struct MedicineReadAttempt: Equatable, Hashable {
    /// `1` for the first attempt, incremented on every retry.
    let attemptNumber: Int
    /// `nil` while the read is still in progress.
    let setback: MedicineReadSetback?

    static let first = MedicineReadAttempt(attemptNumber: 1, setback: nil)

    /// True when the person is being offered a recovery path.
    var isAwaitingRecovery: Bool {
        setback != nil
    }

    func retried() -> MedicineReadAttempt {
        MedicineReadAttempt(attemptNumber: attemptNumber + 1, setback: nil)
    }

    func interrupted(by setback: MedicineReadSetback) -> MedicineReadAttempt {
        MedicineReadAttempt(attemptNumber: attemptNumber, setback: setback)
    }
}

/// How the medicine under review was chosen.
enum MedicineChoiceOrigin: Equatable, Hashable {
    case readFromPhoto
    case chosenFromFrequentList
}

/// A medicine offered for confirmation.
///
/// Demo data only: no dosage, no clinical claim, and no source reference. The
/// real candidate list and its wording come from the server-owned catalog.
struct MedicineCandidate: Equatable, Hashable, Identifiable {
    let id: String
    let displayName: String
    /// A short, non-clinical hint such as packaging appearance.
    let recognitionHint: String
}

struct MedicineConfirmationPrompt: Equatable, Hashable {
    let candidates: [MedicineCandidate]
    let origin: MedicineChoiceOrigin
    /// The read attempt this prompt came from, so taking another photo
    /// continues the attempt count instead of restarting it at 1.
    let attemptNumber: Int
}

struct ConfirmedMedicine: Equatable, Hashable {
    let candidate: MedicineCandidate
    let origin: MedicineChoiceOrigin
}

/// How a companion session finished.
enum CompanionCompletion: Equatable, Hashable {
    case arrivedSafely
    case endedEarly
}

/// The eight steps of one continuous companion session.
///
/// This models the *flow of a session*, not the presentation of a medicine
/// assessment. Risk wording, severity and colour belong to
/// `SlowWalkPresentation` and are deliberately absent here.
enum CompanionFlowState: Equatable, Hashable {
    case notStarted
    case preDepartureCheck
    case scanningMedicine(MedicineReadAttempt)
    case awaitingMedicineConfirmation(MedicineConfirmationPrompt)
    case showingRiskAction(ConfirmedMedicine)
    case travelling
    case approachingStop
    case completed(CompanionCompletion)

    /// True while a session is underway and can still be ended early.
    var isActive: Bool {
        switch self {
        case .notStarted, .completed:
            false
        case .preDepartureCheck,
             .scanningMedicine,
             .awaitingMedicineConfirmation,
             .showingRiskAction,
             .travelling,
             .approachingStop:
            true
        }
    }
}

/// Every input that can move a companion session forward.
enum CompanionFlowEvent: Equatable, Hashable {
    case startCompanion
    case beginMedicineRead
    case medicineReadDidNotSucceed(MedicineReadSetback)
    case retryMedicineRead
    case chooseFromFrequentList([MedicineCandidate])
    case medicineCandidatesReady([MedicineCandidate])
    /// Raised when none of the offered candidates match the box in hand.
    case retakeMedicinePhoto
    case confirmMedicine(MedicineCandidate)
    case acknowledgeCareAction
    case approachStop
    case arriveSafely
    case endEarly
}
