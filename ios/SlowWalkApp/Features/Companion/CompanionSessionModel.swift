import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain

/// Owns the live companion session, asynchronous work, and care records.
@Observable
@MainActor
final class CompanionSessionModel {
    private(set) var state: CompanionFlowState = .notStarted

    private let records: any CareRecordStoring
    private let simulator: any MedicineScanSimulating
    private let readDelay: any MedicineReadDelaying
    private let assessmentRunner: any MedicineAssessmentRunning
    private let plan: TodayPlan
    private let clock: any SlowWalkDomain.Clock
    private let makeRequestID: () -> UUID

    let capabilities: CapabilityCatalog

    private var readGeneration = 0
    private var assessmentGeneration = 0
    private var displayedActionCardRequestIDs = Set<UUID>()

    private(set) var pendingReadTask: Task<Void, Never>?
    private(set) var pendingAssessmentTask: Task<Void, Never>?

    init(
        records: any CareRecordStoring,
        simulator: any MedicineScanSimulating,
        plan: TodayPlan,
        readDelay: any MedicineReadDelaying,
        assessmentRunner: any MedicineAssessmentRunning,
        clock: any SlowWalkDomain.Clock,
        capabilities: CapabilityCatalog,
        makeRequestID: @escaping () -> UUID = UUID.init
    ) {
        self.records = records
        self.simulator = simulator
        self.plan = plan
        self.readDelay = readDelay
        self.assessmentRunner = assessmentRunner
        self.clock = clock
        self.capabilities = capabilities
        self.makeRequestID = makeRequestID
    }

    // MARK: - Presentation values

    var stepLabel: String { CompanionCopy.stepLabel(for: state) }

    var situation: String {
        CompanionCopy.situation(for: state, capabilities: capabilities)
    }

    var nextStep: String { CompanionCopy.nextStep(for: state) }
    var reason: String? { CompanionCopy.reason(for: state) }
    var canEndEarly: Bool { state.isActive }

    var isReadingMedicine: Bool {
        if case .scanningMedicine(let attempt) = state {
            return !attempt.isAwaitingRecovery
        }
        return false
    }

    var assessmentGate: MedicineAssessmentGate? {
        if case .awaitingMedicineAssessment(let gate) = state {
            return gate
        }
        return nil
    }

    var canContinueAfterAssessment: Bool {
        assessmentGate?.hasFinalResult == true
    }

    var canDepart: Bool {
        canContinueAfterAssessment && plan.outing != nil
    }

    /// Candidate identities are projected only from the current canonical
    /// response. No cached or app-authored list can reach Core confirmation.
    var assessmentCandidates: [SlowWalkDomain.MedicineCandidate] {
        guard
            case .requiresMedicineConfirmation(let requirement) =
                assessmentGate?.viewState,
            let response = requirement.response
        else {
            return []
        }
        switch requirement.reason {
        case .ambiguousMedicine, .unresolvedMedicine:
            return response.resolution.candidates
        case .noRecognizedText, .serverRequiresConfirmation:
            return []
        }
    }

    var recoveryOptions: [CompanionRecoveryOption] {
        guard case .scanningMedicine(let attempt) = state,
            attempt.isAwaitingRecovery
        else {
            return []
        }
        return [.retryPhoto, .chooseFromList, .contactSomeone]
    }

    // MARK: - Session intents

    @discardableResult
    func startCompanion() -> Bool {
        guard send(.startCompanion) else { return false }
        invalidatePendingRead()
        invalidatePendingAssessment()
        displayedActionCardRequestIDs.removeAll()
        if let outing = plan.outing {
            records.append(.dayPlanItemStarted(title: outing.title))
        } else {
            records.append(.dayPlanItemStarted(title: "今日用药"))
        }
        return true
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
        let candidates = MedicineCandidate.demoFrequentlyUsed
        guard send(.chooseFromFrequentList(candidates)) else { return }
        invalidatePendingRead()
    }

    func retakeMedicinePhoto() {
        guard send(.retakeMedicinePhoto) else { return }
        invalidatePendingAssessment()
        recordReadStartedAndRun()
    }

    func confirmMedicine(_ candidate: MedicineCandidate) {
        guard case .awaitingMedicineConfirmation(let prompt) = state,
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
        invalidatePendingRead()
        beginMedicineAssessment(for: candidate)
    }

    func reconsiderMedicineChoice() {
        guard send(.reconsiderMedicineChoice) else { return }
        invalidatePendingAssessment()
    }

    func retryMedicineAssessment() {
        guard let gate = assessmentGate else { return }
        switch gate.viewState {
        case .failed(let failure):
            guard failure.isRecoverable else { return }
        case .cancelled:
            break
        case .idle,
            .recognizing,
            .requiresMedicineConfirmation,
            .assessing,
            .result:
            return
        }
        beginMedicineAssessment(for: gate.confirmed.candidate)
    }

    func confirmAssessmentCandidate(candidateID: String) {
        guard assessmentCandidates.contains(where: {
            $0.medicine.id == candidateID
        })
        else {
            return
        }

        beginAssessmentOperation()
        guard send(.medicineAssessmentUpdated(.assessing(startedAt: clock.now())))
        else {
            return
        }

        let generation = assessmentGeneration
        let runner = assessmentRunner
        pendingAssessmentTask = Task { [weak self] in
            let result = await runner.confirmMedicine(candidateID: candidateID)
            guard let self,
                self.assessmentGeneration == generation
            else {
                return
            }
            self.finishMedicineAssessment(result)
        }
    }

    @discardableResult
    func continueAfterMedicineAssessment() -> Bool {
        let hasOuting = plan.outing != nil
        guard send(.continueAfterMedicineAssessment(hasOuting: hasOuting))
        else {
            return false
        }
        if !hasOuting {
            records.append(.companionFinished(.medicineReviewCompleted))
        }
        return true
    }

    func approachStop() {
        guard send(.approachStop) else { return }
    }

    func arriveSafely() {
        guard send(.arriveSafely) else { return }
        records.append(.companionFinished(.arrivedSafely))
    }

    func endEarly() {
        guard send(.endEarly) else { return }
        invalidatePendingRead()
        invalidatePendingAssessment()
        records.append(.companionFinished(.endedEarly))
    }

    /// Called only by the view branch that actually inserted the final
    /// canonical ActionCard into the hierarchy.
    func medicineActionCardDidAppear(requestID: UUID) {
        guard
            case .awaitingMedicineAssessment(let gate) = state,
            case .result(let presentation) = gate.viewState,
            presentation.response.requestID == requestID,
            displayedActionCardRequestIDs.insert(requestID).inserted
        else {
            return
        }

        let medicineName =
            presentation.response.resolution.selectedMedicine?.canonicalName
            ?? presentation.response.actionCard.title
        records.append(.careActionShown(medicineName: medicineName))
    }

    // MARK: - Medicine assessment

    private func beginMedicineAssessment(for candidate: MedicineCandidate) {
        beginAssessmentOperation()
        guard send(.medicineAssessmentUpdated(.assessing(startedAt: clock.now())))
        else {
            return
        }

        let generation = assessmentGeneration
        let requestID = makeRequestID()
        let runner = assessmentRunner
        pendingAssessmentTask = Task { [weak self] in
            let result = await runner.assess(
                medicine: candidate,
                requestID: requestID
            )
            guard let self,
                self.assessmentGeneration == generation
            else {
                return
            }
            self.finishMedicineAssessment(result)
        }
    }

    private func beginAssessmentOperation() {
        pendingAssessmentTask?.cancel()
        pendingAssessmentTask = nil
        assessmentGeneration &+= 1
    }

    private func finishMedicineAssessment(
        _ result: MedicineAssessmentViewState
    ) {
        guard send(.medicineAssessmentUpdated(result)) else { return }
        pendingAssessmentTask = nil

        switch result {
        case .failed, .cancelled:
            records.append(
                .medicineAssessmentDidNotSucceed(.assessmentNotCompleted)
            )
        case .idle,
            .recognizing,
            .requiresMedicineConfirmation,
            .assessing,
            .result:
            break
        }
    }

    private func invalidatePendingAssessment() {
        assessmentGeneration &+= 1
        pendingAssessmentTask?.cancel()
        pendingAssessmentTask = nil
    }

    // MARK: - Simulated read

    private func invalidatePendingRead() {
        readGeneration += 1
        pendingReadTask?.cancel()
        pendingReadTask = nil
    }

    private func recordReadStartedAndRun() {
        guard case .scanningMedicine(let attempt) = state else { return }

        invalidatePendingRead()
        let generation = readGeneration
        let attemptNumber = attempt.attemptNumber
        records.append(.medicineReadStarted(attemptNumber: attemptNumber))

        pendingReadTask = Task { [weak self] in
            do {
                try await self?.readDelay.wait()
            } catch {
                return
            }
            guard let self,
                !Task.isCancelled,
                self.readGeneration == generation
            else {
                return
            }
            self.finishRead(forAttemptNumber: attemptNumber)
        }
    }

    private func finishRead(forAttemptNumber attemptNumber: Int) {
        guard let outcome = simulator.outcome(forAttemptNumber: attemptNumber)
        else {
            return
        }
        switch outcome {
        case .doesNotSucceed(let setback):
            guard send(.medicineReadDidNotSucceed(setback)) else { return }
            records.append(.medicineReadDidNotSucceed(setback))
        case .findsCandidates(let candidates):
            guard send(.medicineCandidatesReady(candidates)) else { return }
            records.append(
                .medicineReadFoundCandidates(candidateCount: candidates.count)
            )
        }
        pendingReadTask = nil
    }

    // MARK: - Transition

    private func send(_ event: CompanionFlowEvent) -> Bool {
        guard let next = CompanionFlowReducer.nextState(from: state, on: event)
        else {
            return false
        }
        state = next
        return true
    }
}

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
