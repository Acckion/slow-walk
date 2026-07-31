import SlowWalkClientCore
import Testing
@testable import SlowWalkApp

@MainActor
struct CompanionFlowStateCoverageTests {
    private enum StateKind: String, CaseIterable {
        case notStarted
        case preDepartureCheck
        case scanningMedicine
        case awaitingMedicineConfirmation
        case awaitingMedicineAssessment
        case travelling
        case approachingStop
        case completed
    }

    private enum EventKind: String, CaseIterable {
        case startCompanion
        case beginMedicineRead
        case medicineReadDidNotSucceed
        case retryMedicineRead
        case chooseFromFrequentList
        case medicineCandidatesReady
        case retakeMedicinePhoto
        case confirmMedicine
        case medicineAssessmentUpdated
        case reconsiderMedicineChoice
        case continueAfterMedicineAssessment
        case approachStop
        case arriveSafely
        case endEarly
    }

    @Test func everyStateFixtureCoversEveryState() {
        let covered = Set(MedicineAssessmentGateTests.everyState.map(stateKind))
        #expect(covered == Set(StateKind.allCases))
    }

    @Test func everyEventFixtureCoversEveryEvent() {
        let covered = Set(MedicineAssessmentGateTests.everyEvent.map(eventKind))
        #expect(covered == Set(EventKind.allCases))
    }

    @Test func everyCanonicalMedicineStateIsInTheFixture() {
        #expect(MedicineAssessmentGateTests.everyViewState.count == 7)
        for state in MedicineAssessmentGateTests.everyViewState {
            switch state {
            case .idle,
                .recognizing,
                .requiresMedicineConfirmation,
                .assessing,
                .result,
                .failed,
                .cancelled:
                break
            }
        }
    }

    @Test func isActiveIsExhaustive() {
        for state in MedicineAssessmentGateTests.everyState {
            switch state {
            case .notStarted, .completed:
                #expect(state.isActive == false)
            case .preDepartureCheck,
                .scanningMedicine,
                .awaitingMedicineConfirmation,
                .awaitingMedicineAssessment,
                .travelling,
                .approachingStop:
                #expect(state.isActive)
            }
        }
    }

    @Test func nonResultStatesNeverReachTravelling() {
        for viewState in MedicineAssessmentGateTests.nonResultViewStates {
            let state = CompanionFlowState.awaitingMedicineAssessment(
                MedicineAssessmentGateTests.makeGate(viewState: viewState)
            )
            for event in MedicineAssessmentGateTests.everyEvent {
                #expect(
                    CompanionFlowReducer.nextState(from: state, on: event)
                        != .travelling
                )
            }
        }
    }

    @Test func recordReasonVocabularyStaysNonMedical() {
        for reason in CareRecordIncompleteReason.allCases {
            switch reason {
            case .assessmentNotCompleted:
                break
            }
        }
        #expect(CareRecordIncompleteReason.allCases.count == 1)
    }

    @Test func completionCopyCoversEveryCompletion() {
        let completions: [CompanionCompletion] = [
            .arrivedSafely,
            .medicineReviewCompleted,
            .endedEarly,
        ]
        for completion in completions {
            let state = CompanionFlowState.completed(completion)
            #expect(CompanionCopy.stepLabel(for: state).isEmpty == false)
            #expect(
                CompanionCopy.situation(
                    for: state,
                    capabilities: .phase0
                ).isEmpty == false
            )
        }
    }

    private func stateKind(_ state: CompanionFlowState) -> StateKind {
        switch state {
        case .notStarted: .notStarted
        case .preDepartureCheck: .preDepartureCheck
        case .scanningMedicine: .scanningMedicine
        case .awaitingMedicineConfirmation: .awaitingMedicineConfirmation
        case .awaitingMedicineAssessment: .awaitingMedicineAssessment
        case .travelling: .travelling
        case .approachingStop: .approachingStop
        case .completed: .completed
        }
    }

    private func eventKind(_ event: CompanionFlowEvent) -> EventKind {
        switch event {
        case .startCompanion: .startCompanion
        case .beginMedicineRead: .beginMedicineRead
        case .medicineReadDidNotSucceed: .medicineReadDidNotSucceed
        case .retryMedicineRead: .retryMedicineRead
        case .chooseFromFrequentList: .chooseFromFrequentList
        case .medicineCandidatesReady: .medicineCandidatesReady
        case .retakeMedicinePhoto: .retakeMedicinePhoto
        case .confirmMedicine: .confirmMedicine
        case .medicineAssessmentUpdated: .medicineAssessmentUpdated
        case .reconsiderMedicineChoice: .reconsiderMedicineChoice
        case .continueAfterMedicineAssessment: .continueAfterMedicineAssessment
        case .approachStop: .approachStop
        case .arriveSafely: .arriveSafely
        case .endEarly: .endEarly
        }
    }
}
