import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain

/// Owns companion navigation and mirrors the coordinator's canonical medicine
/// ViewState for SwiftUI. No App-specific medicine result state exists.
@Observable
@MainActor
final class CompanionSessionModel {
    private(set) var state: CompanionFlowState = .notStarted
    private(set) var medicineState: MedicineAssessmentViewState = .idle
    private(set) var pendingAssessmentTask: Task<Void, Never>?

    private let records: any CareRecordStoring
    private let coordinator: MedicineAssessmentCoordinator
    private let medicineInput: DemoMedicineAssessmentInput
    private let plan: TodayPlan
    private var assessmentGeneration = 0
    private var pendingConfirmedMedicineName: String?
    private var stateObservationTask: Task<Void, Never>?
    private var lastCoordinatorSequenceNumber: UInt64 = 0
    private var lastCoordinatorStateRank = 0

    init(
        records: any CareRecordStoring,
        coordinator: MedicineAssessmentCoordinator,
        medicineInput: DemoMedicineAssessmentInput,
        plan: TodayPlan
    ) {
        self.records = records
        self.coordinator = coordinator
        self.medicineInput = medicineInput
        self.plan = plan
        stateObservationTask = Task { [weak self, coordinator] in
            let updates = await coordinator.stateUpdates()
            for await update in updates {
                guard !Task.isCancelled else { return }
                self?.receiveMedicineUpdate(update)
            }
        }
    }

    var stepLabel: String {
        CompanionCopy.stepLabel(for: state, medicineState: medicineState)
    }

    var situation: String {
        CompanionCopy.situation(for: state, medicineState: medicineState)
    }

    var nextStep: String {
        CompanionCopy.nextStep(for: state, medicineState: medicineState)
    }

    var reason: String? {
        CompanionCopy.reason(for: state, medicineState: medicineState)
    }

    var canEndEarly: Bool { state.isActive }

    var assessedMedicineID: String? {
        guard case .result(let presentation) = medicineState else { return nil }
        return presentation.response.resolution.selectedMedicine?.id
    }

    var isMedicineAssessmentCancelled: Bool {
        if case .cancelled = medicineState { return true }
        return false
    }

    var canRetryMedicineAssessment: Bool {
        guard case .medicineAssessment = state else { return false }
        switch medicineState {
        case .requiresMedicineConfirmation, .failed, .cancelled:
            return true
        case .idle, .recognizing, .assessing, .result:
            return false
        }
    }

    @discardableResult
    func startCompanion() -> Bool {
        guard send(.startCompanion) else { return false }
        invalidateAssessment()
        medicineState = .idle
        if let outing = plan.outing {
            records.append(.dayPlanItemStarted(title: outing.title))
        } else {
            records.append(.dayPlanItemStarted(title: "今日用药"))
        }
        return true
    }

    func beginMedicineAssessment() {
        guard send(.beginMedicineAssessment) else { return }
        runMedicineAssessment()
    }

    func retryMedicineAssessment() {
        guard canRetryMedicineAssessment else { return }
        runMedicineAssessment()
    }

    func confirmMedicine(_ candidate: SlowWalkDomain.MedicineCandidate) {
        guard case .requiresMedicineConfirmation(let requirement) = medicineState,
            requirement.response?.resolution.candidates.contains(candidate) == true
        else {
            return
        }

        invalidateAssessment()
        let generation = assessmentGeneration
        pendingConfirmedMedicineName = candidate.medicine.canonicalName
        pendingAssessmentTask = Task { [weak self, coordinator] in
            _ = await coordinator.confirmMedicine(
                candidateID: candidate.medicine.id
            )
            guard !Task.isCancelled,
                let self,
                self.assessmentGeneration == generation
            else {
                return
            }
            let update = await coordinator.currentStateUpdate
            self.receiveMedicineUpdate(update)
        }
    }

    @discardableResult
    func acknowledgeCareAction() -> Bool {
        guard case .result = medicineState,
            send(.acknowledgeCareAction(hasOuting: plan.outing != nil))
        else {
            return false
        }
        if plan.outing == nil {
            records.append(.companionFinished(.medicineReviewed))
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
        invalidateAssessment()
        medicineState = .cancelled
        Task { [coordinator] in
            await coordinator.cancelCurrentAssessment()
        }
        records.append(.companionFinished(.endedEarly))
    }

    /// Stops in-flight work when the app is no longer active without ending
    /// the whole companion session or accepting a late result.
    func cancelPendingMedicineAssessment() {
        guard case .medicineAssessment = state else { return }
        switch medicineState {
        case .idle, .recognizing, .assessing:
            guard pendingAssessmentTask != nil else { return }
            invalidateAssessment()
            medicineState = .cancelled
            Task { [coordinator] in
                await coordinator.cancelCurrentAssessment()
            }
        case .requiresMedicineConfirmation, .result, .failed, .cancelled:
            return
        }
    }

    private func runMedicineAssessment() {
        invalidateAssessment()
        let generation = assessmentGeneration
        pendingConfirmedMedicineName = nil
        records.append(.medicineAssessmentStarted)

        pendingAssessmentTask = Task {
            _ = await coordinator.assess(
                imageInput: medicineInput.imageInput,
                userProfile: medicineInput.userProfile,
                recentRecords: medicineInput.recentRecords,
                requestID: UUID()
            )
            guard !Task.isCancelled,
                assessmentGeneration == generation
            else {
                return
            }
            let update = await coordinator.currentStateUpdate
            receiveMedicineUpdate(update)
        }
    }

    private func receiveMedicineUpdate(
        _ update: MedicineAssessmentStateUpdate
    ) {
        let rank = Self.stateRank(update.state)
        guard update.sequenceNumber >= lastCoordinatorSequenceNumber else {
            return
        }
        if update.sequenceNumber == lastCoordinatorSequenceNumber,
            rank < lastCoordinatorStateRank
        {
            return
        }
        lastCoordinatorSequenceNumber = update.sequenceNumber
        lastCoordinatorStateRank = rank
        receiveMedicineState(update.state)
    }

    private func receiveMedicineState(_ newState: MedicineAssessmentViewState) {
        guard case .medicineAssessment = state,
            medicineState != newState
        else {
            return
        }

        medicineState = newState

        switch newState {
        case .requiresMedicineConfirmation(let requirement):
            if requirement.reason == .serverRequiresConfirmation {
                records.append(.medicineAssessmentRequiresSourceReview)
            } else {
                let count = requirement.response?.resolution.candidates.count ?? 0
                records.append(
                    .medicineAssessmentNeedsConfirmation(candidateCount: count)
                )
            }

        case .result(let presentation):
            let name =
                presentation.response.resolution.selectedMedicine?
                .canonicalName ?? presentation.response.actionCard.title
            if let confirmedName = pendingConfirmedMedicineName {
                records.append(.medicineConfirmed(medicineName: confirmedName))
            }
            pendingConfirmedMedicineName = nil
            records.append(.careActionShown(medicineName: name))

        case .failed(let failure):
            pendingConfirmedMedicineName = nil
            records.append(
                .medicineAssessmentFailed(isRecoverable: failure.isRecoverable)
            )

        case .cancelled:
            pendingConfirmedMedicineName = nil

        case .idle, .recognizing, .assessing:
            break
        }
    }

    private func invalidateAssessment() {
        assessmentGeneration += 1
        pendingAssessmentTask?.cancel()
        pendingAssessmentTask = nil
    }

    private static func stateRank(
        _ state: MedicineAssessmentViewState
    ) -> Int {
        switch state {
        case .idle:
            0
        case .recognizing:
            1
        case .assessing:
            2
        case .requiresMedicineConfirmation, .result, .failed, .cancelled:
            3
        }
    }

    private func send(_ event: CompanionFlowEvent) -> Bool {
        guard let next = CompanionFlowReducer.nextState(from: state, on: event) else {
            return false
        }
        state = next
        return true
    }
}
