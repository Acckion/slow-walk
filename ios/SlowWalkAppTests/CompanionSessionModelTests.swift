import Foundation
import SlowWalkClientCore
import Testing

@testable import SlowWalkApp

@MainActor
struct CompanionSessionModelTests {
    @Test func startReportsWhetherTransitionSucceeded() {
        let environment = makeEnvironment()

        #expect(environment.companion.startCompanion())
        #expect(!environment.companion.startCompanion())
        #expect(environment.companion.state == .preDepartureCheck)

        let starts = environment.careRecords.events.filter {
            if case .dayPlanItemStarted = $0.kind { return true }
            return false
        }
        #expect(starts.count == 1)
    }

    @Test func presetInputProducesCanonicalResultAndRealActionRecord() async {
        let environment = makeEnvironment()
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        await waitForAssessment(session)

        #expect(session.assessedMedicineID == "demo-acetaminophen")
        #expect(session.state == .medicineAssessment)

        let actionRecords = environment.careRecords.events.filter {
            if case .careActionShown = $0.kind { return true }
            return false
        }
        #expect(actionRecords.count == 1)
    }

    @Test func cannotAdvanceBeforeCanonicalResultExists() {
        let environment = makeEnvironment()
        let session = environment.companion

        #expect(session.startCompanion())
        #expect(!session.acknowledgeCareAction())
        #expect(session.state == .preDepartureCheck)
    }

    @Test func repeatedBeginStartsOnlyOneAssessment() async {
        let environment = makeEnvironment()
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        session.beginMedicineAssessment()
        await waitForAssessment(session)

        let starts = environment.careRecords.events.filter {
            $0.kind == .medicineAssessmentStarted
        }
        #expect(starts.count == 1)
    }

    @Test func medicineOnlyPlanCompletesWithoutEnteringTravel() async {
        let environment = makeEnvironment(plan: .medicineOnlyDemo)
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        await waitForAssessment(session)

        #expect(session.acknowledgeCareAction())
        #expect(session.state == .completed(.medicineReviewed))
        #expect(
            environment.careRecords.events.last?.kind
                == .companionFinished(.medicineReviewed)
        )
    }

    @Test func medicineOnlyAcknowledgementCannotDoubleFinish() async {
        let environment = makeEnvironment(plan: .medicineOnlyDemo)
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        await waitForAssessment(session)

        #expect(session.acknowledgeCareAction())
        #expect(!session.acknowledgeCareAction())
        let finishes = environment.careRecords.events.filter {
            $0.kind == .companionFinished(.medicineReviewed)
        }
        #expect(finishes.count == 1)
    }

    @Test func startingNewSessionClearsPreviousMedicineResult() async {
        let environment = makeEnvironment(plan: .medicineOnlyDemo)
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        await waitForAssessment(session)
        #expect(session.acknowledgeCareAction())
        #expect(session.assessedMedicineID == "demo-acetaminophen")

        #expect(session.startCompanion())
        #expect(session.assessedMedicineID == nil)
        #expect(session.state == .preDepartureCheck)
    }

    @Test func planWithOutingContinuesOnlyAfterCanonicalResult() async {
        let environment = makeEnvironment()
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        await waitForAssessment(session)

        #expect(session.acknowledgeCareAction())
        #expect(session.state == .travelling)
    }

    @Test func endingEarlyInvalidatesPendingAssessment() async {
        let environment = makeEnvironment()
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        let abandonedTask = session.pendingAssessmentTask
        session.endEarly()
        if let abandonedTask { await abandonedTask.value }

        #expect(session.state == .completed(.endedEarly))
        #expect(session.isMedicineAssessmentCancelled)
        #expect(
            environment.careRecords.events.contains {
                if case .careActionShown = $0.kind { return true }
                return false
            } == false
        )
    }

    @Test func becomingInactiveCancelsOnlyPendingAssessment() async {
        let environment = makeEnvironment()
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        let abandonedTask = session.pendingAssessmentTask
        session.cancelPendingMedicineAssessment()
        if let abandonedTask { await abandonedTask.value }

        #expect(session.state == .medicineAssessment)
        #expect(session.isMedicineAssessmentCancelled)
        #expect(
            environment.careRecords.events.contains {
                if case .careActionShown = $0.kind { return true }
                return false
            } == false
        )
    }

    @Test func immediateRetryWaitsForCoordinatorCancellation() async {
        let environment = makeEnvironment()
        let session = environment.companion

        #expect(session.startCompanion())
        session.beginMedicineAssessment()
        session.cancelPendingMedicineAssessment()
        #expect(session.isMedicineAssessmentCancelled)

        session.retryMedicineAssessment()
        await waitForAssessment(session)

        #expect(session.assessedMedicineID == "demo-acetaminophen")
        #expect(session.state == .medicineAssessment)
    }

    @Test func riskIconsDoNotUseSuccessSymbolForWarnings() {
        #expect(
            CareActionPresentationSlot.riskSystemImage(for: .routine)
                == "checkmark.shield.fill"
        )
        #expect(
            CareActionPresentationSlot.riskSystemImage(for: .reviewRequired)
                == "exclamationmark.triangle"
        )
        #expect(
            CareActionPresentationSlot.riskSystemImage(for: .urgentAttention)
                == "exclamationmark.triangle.fill"
        )
        #expect(
            CareActionPresentationSlot.riskSystemImage(for: .immediateAttention)
                == "exclamationmark.octagon.fill"
        )
    }

    private func makeEnvironment(
        plan: TodayPlan = .demo
    ) -> AppEnvironment {
        AppEnvironment(
            clock: AppFixedClock(
                fixedDate: Date(timeIntervalSince1970: 1_753_000_000)
            ),
            plan: plan
        )
    }

    private func waitForAssessment(
        _ session: CompanionSessionModel
    ) async {
        guard let task = session.pendingAssessmentTask else {
            Issue.record("assessment task was not started")
            return
        }
        await task.value
    }
}

extension TodayPlan {
    fileprivate static let medicineOnlyDemo = TodayPlan(
        preferredName: "演示用户",
        medicines: [
            TodayMedicineItem(
                id: "medicine-only-demo",
                displayName: "对乙酰氨基酚（演示）",
                timeOfDayDescription: "演示安排",
                isTakenToday: false
            )
        ],
        outing: nil
    )
}
