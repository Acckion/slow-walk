import Foundation
import SlowWalkClientCore

/// Pure transition table for one companion session.
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

        case (.preDepartureCheck, .beginMedicineRead):
            return .scanningMedicine(.first)

        case let (
            .scanningMedicine(attempt),
            .medicineReadDidNotSucceed(setback)
        ):
            guard !attempt.isAwaitingRecovery else { return nil }
            return .scanningMedicine(attempt.interrupted(by: setback))

        case let (.scanningMedicine(attempt), .retryMedicineRead):
            guard attempt.isAwaitingRecovery else { return nil }
            return .scanningMedicine(attempt.retried())

        case let (
            .scanningMedicine(attempt),
            .medicineCandidatesReady(candidates)
        ):
            guard !attempt.isAwaitingRecovery, !candidates.isEmpty else {
                return nil
            }
            return .awaitingMedicineConfirmation(
                MedicineConfirmationPrompt(
                    candidates: candidates,
                    origin: .readFromPhoto,
                    attemptNumber: attempt.attemptNumber
                )
            )

        case let (
            .scanningMedicine(attempt),
            .chooseFromFrequentList(candidates)
        ):
            guard !candidates.isEmpty else { return nil }
            return .awaitingMedicineConfirmation(
                MedicineConfirmationPrompt(
                    candidates: candidates,
                    origin: .chosenFromFrequentList,
                    attemptNumber: attempt.attemptNumber
                )
            )

        case let (
            .awaitingMedicineConfirmation(prompt),
            .retakeMedicinePhoto
        ):
            return .scanningMedicine(
                MedicineReadAttempt(
                    attemptNumber: prompt.attemptNumber + 1,
                    setback: nil
                )
            )

        case let (
            .awaitingMedicineConfirmation(prompt),
            .confirmMedicine(candidate)
        ):
            guard prompt.candidates.contains(candidate) else { return nil }
            return .awaitingMedicineAssessment(
                MedicineAssessmentGate(
                    confirmed: ConfirmedMedicine(
                        candidate: candidate,
                        origin: prompt.origin
                    ),
                    prompt: prompt,
                    viewState: .idle
                )
            )

        case let (
            .awaitingMedicineAssessment(gate),
            .medicineAssessmentUpdated(viewState)
        ):
            return .awaitingMedicineAssessment(
                gate.updating(viewState: viewState)
            )

        case let (
            .awaitingMedicineAssessment(gate),
            .reconsiderMedicineChoice
        ):
            return .awaitingMedicineConfirmation(gate.prompt)

        case let (
            .awaitingMedicineAssessment(gate),
            .retakeMedicinePhoto
        ):
            return .scanningMedicine(
                MedicineReadAttempt(
                    attemptNumber: gate.prompt.attemptNumber + 1,
                    setback: nil
                )
            )

        case let (
            .awaitingMedicineAssessment(gate),
            .continueAfterMedicineAssessment(hasOuting)
        ):
            guard gate.hasFinalResult else { return nil }
            return hasOuting
                ? .travelling
                : .completed(.medicineReviewCompleted)

        case (.travelling, .approachStop):
            return .approachingStop

        case (.approachingStop, .arriveSafely):
            return .completed(.arrivedSafely)

        default:
            return nil
        }
    }
}
