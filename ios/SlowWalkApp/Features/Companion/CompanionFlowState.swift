import Foundation

/// How a companion session finished.
enum CompanionCompletion: Equatable, Hashable {
    /// The medicine-only plan reached its action card and was acknowledged.
    case medicineReviewed
    case arrivedSafely
    case endedEarly
}

/// Navigation phases for one continuous companion session.
///
/// Medicine recognition, confirmation, assessment, and failure details are
/// intentionally absent. `MedicineAssessmentViewState` is the only source of
/// truth for those states.
enum CompanionFlowState: Equatable, Hashable {
    case notStarted
    case preDepartureCheck
    case medicineAssessment
    case travelling
    case approachingStop
    case completed(CompanionCompletion)

    var isActive: Bool {
        switch self {
        case .notStarted, .completed:
            false
        case .preDepartureCheck,
            .medicineAssessment,
            .travelling,
            .approachingStop:
            true
        @unknown default:
            false
        }
    }
}

/// Inputs that can move the companion session between navigation phases.
enum CompanionFlowEvent: Equatable, Hashable {
    case startCompanion
    case beginMedicineAssessment
    case acknowledgeCareAction(hasOuting: Bool)
    case approachStop
    case arriveSafely
    case endEarly
}
