import Foundation
import SlowWalkDomain
import Testing

@testable import SlowWalkApp

@MainActor
struct CareRecordStoreTests {
    @Test func appendPreservesOrderAndInjectedTime() {
        let fixed = Date(timeIntervalSince1970: 1_753_000_000)
        let store = InMemoryCareRecordStore(
            clock: AppFixedClock(fixedDate: fixed)
        )

        store.append(.dayPlanItemStarted(title: "演示安排"))
        store.append(.medicineAssessmentStarted)
        store.append(.careActionShown(medicineName: "演示药品"))

        #expect(
            store.events.map(\.kind) == [
                .dayPlanItemStarted(title: "演示安排"),
                .medicineAssessmentStarted,
                .careActionShown(medicineName: "演示药品"),
            ])
        #expect(store.events.allSatisfy { $0.occurredAt == fixed })
    }

    @Test func candidateRecordCarriesCountNotCandidateIdentity() {
        let store = makeStore()
        store.append(.medicineAssessmentNeedsConfirmation(candidateCount: 3))

        guard
            case .medicineAssessmentNeedsConfirmation(let count)? =
                store.events.first?.kind
        else {
            Issue.record("expected confirmation requirement")
            return
        }
        #expect(count == 3)
    }

    @Test func sourceReviewRecordDoesNotPretendCandidateConfirmation() {
        let store = makeStore()

        store.append(.medicineAssessmentRequiresSourceReview)

        #expect(
            store.events.last?.kind
                == .medicineAssessmentRequiresSourceReview
        )
    }

    @Test func actionRecordCarriesNameWithoutRiskOrDose() {
        let store = makeStore()
        store.append(.careActionShown(medicineName: "演示药品"))

        guard case .careActionShown(let name)? = store.events.first?.kind else {
            Issue.record("expected action record")
            return
        }
        #expect(name == "演示药品")
    }

    @Test func confirmedRecordCarriesCanonicalNameOnly() {
        let store = makeStore()
        store.append(.medicineConfirmed(medicineName: "Acetaminophen"))

        guard case .medicineConfirmed(let name)? = store.events.first?.kind else {
            Issue.record("expected confirmation record")
            return
        }
        #expect(name == "Acetaminophen")
    }

    @Test func failureRecordCarriesOnlyRecoverability() {
        let store = makeStore()
        store.append(.medicineAssessmentFailed(isRecoverable: true))

        guard
            case .medicineAssessmentFailed(let isRecoverable)? =
                store.events.first?.kind
        else {
            Issue.record("expected failure record")
            return
        }
        #expect(isRecoverable)
    }

    @Test func finishedRecordSupportsMedicineOnlyCompletion() {
        let store = makeStore()
        store.append(.companionFinished(.medicineReviewed))
        #expect(store.events.first?.kind == .companionFinished(.medicineReviewed))
    }

    private func makeStore() -> InMemoryCareRecordStore {
        InMemoryCareRecordStore(
            clock: AppFixedClock(
                fixedDate: Date(timeIntervalSince1970: 1)
            )
        )
    }
}
