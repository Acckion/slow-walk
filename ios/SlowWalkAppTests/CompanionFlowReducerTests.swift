import Testing

@testable import SlowWalkApp

@MainActor
struct CompanionFlowReducerTests {
    @Test func sessionCanStartFromInitialAndCompletedStates() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .notStarted,
                on: .startCompanion
            ) == .preDepartureCheck
        )
        #expect(
            CompanionFlowReducer.nextState(
                from: .completed(.medicineReviewed),
                on: .startCompanion
            ) == .preDepartureCheck
        )
    }

    @Test func activeSessionRejectsRepeatedStart() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .preDepartureCheck,
                on: .startCompanion
            ) == nil
        )
    }

    @Test func medicineAssessmentBeginsOnlyAfterPreDepartureCheck() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .preDepartureCheck,
                on: .beginMedicineAssessment
            ) == .medicineAssessment
        )
        #expect(
            CompanionFlowReducer.nextState(
                from: .notStarted,
                on: .beginMedicineAssessment
            ) == nil
        )
    }

    @Test func acknowledgedMedicineOnlyPlanCompletesWithoutTravelling() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .medicineAssessment,
                on: .acknowledgeCareAction(hasOuting: false)
            ) == .completed(.medicineReviewed)
        )
    }

    @Test func acknowledgedPlanWithOutingContinuesToTravel() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .medicineAssessment,
                on: .acknowledgeCareAction(hasOuting: true)
            ) == .travelling
        )
    }

    @Test func acknowledgementIsRejectedOutsideMedicinePhase() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .preDepartureCheck,
                on: .acknowledgeCareAction(hasOuting: true)
            ) == nil
        )
    }

    @Test func outingProgressesInOrder() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .travelling,
                on: .approachStop
            ) == .approachingStop
        )
        #expect(
            CompanionFlowReducer.nextState(
                from: .approachingStop,
                on: .arriveSafely
            ) == .completed(.arrivedSafely)
        )
    }

    @Test func outOfOrderOutingEventsAreRejected() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .preDepartureCheck,
                on: .approachStop
            ) == nil
        )
        #expect(
            CompanionFlowReducer.nextState(
                from: .travelling,
                on: .arriveSafely
            ) == nil
        )
    }

    @Test func endEarlyAppliesOnlyToActiveStates() {
        #expect(
            CompanionFlowReducer.nextState(
                from: .medicineAssessment,
                on: .endEarly
            ) == .completed(.endedEarly)
        )
        #expect(
            CompanionFlowReducer.nextState(
                from: .notStarted,
                on: .endEarly
            ) == nil
        )
    }

    @Test func isActiveCoversEveryCase() {
        let inactive: [CompanionFlowState] = [
            .notStarted,
            .completed(.medicineReviewed),
            .completed(.arrivedSafely),
            .completed(.endedEarly),
        ]
        let active: [CompanionFlowState] = [
            .preDepartureCheck,
            .medicineAssessment,
            .travelling,
            .approachingStop,
        ]

        #expect(inactive.allSatisfy { !$0.isActive })
        #expect(active.allSatisfy { $0.isActive })
    }
}
