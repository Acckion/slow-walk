import Foundation

/// The single place where companion flow transitions are decided.
///
/// `nextState(from:on:)` is a pure function: it reads no clock, writes no
/// records, and starts no work. Side effects belong to
/// `CompanionSessionModel`, which keeps this logic reviewable and testable on
/// its own.
///
/// - Note: The project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
///   so this type is main-actor isolated like the rest of the app. It holds no
///   state, so a future test target can exercise it directly from
///   `@MainActor` tests.
enum CompanionFlowReducer {
    /// Returns the next state, or `nil` when the event does not apply.
    ///
    /// Returning `nil` rather than throwing lets callers ignore stale or
    /// repeated input without any side effect.
    static func nextState(
        from state: CompanionFlowState,
        on event: CompanionFlowEvent
    ) -> CompanionFlowState? {
        // Ending early is available from any step that is underway.
        if case .endEarly = event {
            return state.isActive ? .completed(.endedEarly) : nil
        }

        switch (state, event) {
        case (.notStarted, .startCompanion),
             (.completed, .startCompanion):
            // A finished session can be followed by a new one; the previous
            // session stays in the care records.
            return .preDepartureCheck

        case (.preDepartureCheck, .beginMedicineRead):
            return .scanningMedicine(.first)

        case let (.scanningMedicine(attempt), .medicineReadDidNotSucceed(setback)):
            guard !attempt.isAwaitingRecovery else { return nil }
            return .scanningMedicine(attempt.interrupted(by: setback))

        case let (.scanningMedicine(attempt), .retryMedicineRead):
            guard attempt.isAwaitingRecovery else { return nil }
            return .scanningMedicine(attempt.retried())

        case let (.scanningMedicine(attempt), .medicineCandidatesReady(candidates)):
            guard !attempt.isAwaitingRecovery, !candidates.isEmpty else { return nil }
            return .awaitingMedicineConfirmation(
                MedicineConfirmationPrompt(
                    candidates: candidates,
                    origin: .readFromPhoto,
                    attemptNumber: attempt.attemptNumber
                )
            )

        case let (.scanningMedicine(attempt), .chooseFromFrequentList(candidates)):
            guard !candidates.isEmpty else { return nil }
            return .awaitingMedicineConfirmation(
                MedicineConfirmationPrompt(
                    candidates: candidates,
                    origin: .chosenFromFrequentList,
                    attemptNumber: attempt.attemptNumber
                )
            )

        case let (.awaitingMedicineConfirmation(prompt), .retakeMedicinePhoto):
            // None of the offered candidates matched the box in hand. Going
            // back to reading is the recovery path the confirmation step
            // promises, so this step is never a dead end.
            return .scanningMedicine(
                MedicineReadAttempt(
                    attemptNumber: prompt.attemptNumber + 1,
                    setback: nil
                )
            )

        case let (.awaitingMedicineConfirmation(prompt), .confirmMedicine(candidate)):
            guard prompt.candidates.contains(candidate) else { return nil }
            return .showingRiskAction(
                ConfirmedMedicine(candidate: candidate, origin: prompt.origin)
            )

        case (.showingRiskAction, .acknowledgeCareAction):
            return .travelling

        case (.travelling, .approachStop):
            return .approachingStop

        case (.approachingStop, .arriveSafely):
            return .completed(.arrivedSafely)

        default:
            return nil
        }
    }
}
