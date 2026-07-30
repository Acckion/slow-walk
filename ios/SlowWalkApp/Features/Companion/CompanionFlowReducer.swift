import Foundation

/// Pure transition table for companion navigation.
///
/// Whether a medicine assessment may be acknowledged is checked against the
/// canonical medicine ViewState by `CompanionSessionModel` before this reducer
/// receives the event.
enum CompanionFlowReducer {
    static func nextState(
        from state: CompanionFlowState,
        on event: CompanionFlowEvent
    ) -> CompanionFlowState? {
        if case .endEarly = event {
            return state.isActive ? .completed(.endedEarly) : nil
        }

        switch (state, event) {
        case (.notStarted, .startCompanion),
            (.completed, .startCompanion):
            return .preDepartureCheck

        case (.preDepartureCheck, .beginMedicineAssessment):
            return .medicineAssessment

        case (.medicineAssessment, .acknowledgeCareAction(let hasOuting)):
            return hasOuting ? .travelling : .completed(.medicineReviewed)

        case (.travelling, .approachStop):
            return .approachingStop

        case (.approachingStop, .arriveSafely):
            return .completed(.arrivedSafely)

        default:
            return nil
        }
    }
}
