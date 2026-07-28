import Foundation

/// Owns the live companion session: current state, side effects, and records.
///
/// All transition decisions come from `CompanionFlowReducer`. This type adds
/// only what a pure function cannot do — write care records and run the
/// simulated read — so the two concerns stay separable.
@Observable
@MainActor
final class CompanionSessionModel {
    private(set) var state: CompanionFlowState = .notStarted

    private let records: any CareRecordStoring
    private let simulator: MockMedicineScanSimulator
    private let plan: TodayPlan

    /// Guards against a stale simulated read landing after the person has
    /// already moved on (retried, chosen from the list, or ended the session).
    private var readGeneration = 0

    init(
        records: any CareRecordStoring,
        simulator: MockMedicineScanSimulator,
        plan: TodayPlan
    ) {
        self.records = records
        self.simulator = simulator
        self.plan = plan
    }

    // MARK: - Derived presentation values

    var stepLabel: String { CompanionCopy.stepLabel(for: state) }
    var situation: String { CompanionCopy.situation(for: state) }
    var nextStep: String { CompanionCopy.nextStep(for: state) }
    var reason: String? { CompanionCopy.reason(for: state) }

    var canEndEarly: Bool { state.isActive }

    /// True while the simulated read is running, so the view can show progress.
    var isReadingMedicine: Bool {
        if case let .scanningMedicine(attempt) = state {
            return !attempt.isAwaitingRecovery
        }
        return false
    }

    /// Recovery choices offered when a read did not succeed.
    var recoveryOptions: [CompanionRecoveryOption] {
        guard case let .scanningMedicine(attempt) = state,
              attempt.isAwaitingRecovery
        else {
            return []
        }
        return [.retryPhoto, .chooseFromList, .contactSomeone]
    }

    // MARK: - Intents

    func startCompanion() {
        guard send(.startCompanion) else { return }
        if let outing = plan.outing {
            records.append(.dayPlanItemStarted(title: outing.title))
        } else {
            records.append(.dayPlanItemStarted(title: "今日用药"))
        }
    }

    func beginMedicineRead() {
        guard send(.beginMedicineRead) else { return }
        recordReadStartedAndRun()
    }

    func retryMedicineRead() {
        guard send(.retryMedicineRead) else { return }
        recordReadStartedAndRun()
    }

    func chooseFromFrequentList() {
        readGeneration += 1
        _ = send(.chooseFromFrequentList(MedicineCandidate.demoFrequentlyUsed))
    }

    /// Goes back to reading when none of the offered candidates match.
    func retakeMedicinePhoto() {
        guard send(.retakeMedicinePhoto) else { return }
        recordReadStartedAndRun()
    }

    func confirmMedicine(_ candidate: MedicineCandidate) {
        guard case let .awaitingMedicineConfirmation(prompt) = state,
              send(.confirmMedicine(candidate))
        else {
            return
        }
        records.append(
            .medicineConfirmed(
                medicineName: candidate.displayName,
                origin: prompt.origin
            )
        )
        records.append(.careActionShown(medicineName: candidate.displayName))
    }

    func acknowledgeCareAction() {
        _ = send(.acknowledgeCareAction)
    }

    func approachStop() {
        _ = send(.approachStop)
    }

    func arriveSafely() {
        guard send(.arriveSafely) else { return }
        records.append(.companionFinished(.arrivedSafely))
    }

    func endEarly() {
        readGeneration += 1
        guard send(.endEarly) else { return }
        records.append(.companionFinished(.endedEarly))
    }

    // MARK: - Simulated read

    private func recordReadStartedAndRun() {
        guard case let .scanningMedicine(attempt) = state else { return }
        records.append(.medicineReadStarted(attemptNumber: attempt.attemptNumber))

        readGeneration += 1
        let generation = readGeneration
        let attemptNumber = attempt.attemptNumber

        Task { [weak self] in
            try? await Task.sleep(for: MockMedicineScanSimulator.simulatedReadDuration)
            guard let self, self.readGeneration == generation else { return }
            self.finishRead(forAttemptNumber: attemptNumber)
        }
    }

    private func finishRead(forAttemptNumber attemptNumber: Int) {
        guard let outcome = simulator.outcome(forAttemptNumber: attemptNumber) else {
            return
        }
        switch outcome {
        case let .doesNotSucceed(setback):
            guard send(.medicineReadDidNotSucceed(setback)) else { return }
            records.append(.medicineReadDidNotSucceed(setback))
        case let .findsCandidates(candidates):
            guard send(.medicineCandidatesReady(candidates)) else { return }
            records.append(
                .medicineReadFoundCandidates(candidateCount: candidates.count)
            )
        }
    }

    // MARK: - Transition

    /// Applies an event, returning whether it changed the state.
    @discardableResult
    private func send(_ event: CompanionFlowEvent) -> Bool {
        guard let next = CompanionFlowReducer.nextState(from: state, on: event) else {
            return false
        }
        state = next
        return true
    }
}

/// A recovery choice offered after a read that did not succeed.
enum CompanionRecoveryOption: Identifiable, Equatable, Hashable, CaseIterable {
    case retryPhoto
    case chooseFromList
    case contactSomeone

    var id: Self { self }

    var title: String {
        switch self {
        case .retryPhoto: CompanionCopy.retryPhotoTitle
        case .chooseFromList: CompanionCopy.chooseFromListTitle
        case .contactSomeone: CompanionCopy.contactSomeoneTitle
        }
    }
}
