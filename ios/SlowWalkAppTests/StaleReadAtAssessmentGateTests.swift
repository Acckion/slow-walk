import Testing
@testable import SlowWalkApp

@MainActor
struct StaleReadAtAssessmentGateTests {
    @Test func staleReadDoesNotOverwriteAssessmentGate() async {
        let spy = SpyScanSimulator(
            scriptedOutcome: .findsCandidates(MedicineCandidate.demoCandidates)
        )
        let delay = ControllableReadDelay()
        let session = makeTestSession(
            simulator: spy,
            readDelay: delay
        )

        #expect(session.startCompanion())
        session.beginMedicineRead()
        await delay.waitForInstall()
        let staleRead = session.pendingReadTask

        session.chooseFromFrequentList()
        session.confirmMedicine(MedicineCandidate.demoFrequentlyUsed[0])
        #expect(session.assessmentGate != nil)

        #expect(delay.release())
        if let staleRead { await staleRead.value }

        #expect(spy.outcomeCalls.isEmpty)
        #expect(session.assessmentGate != nil)
        #expect(session.state != .travelling)
    }

    @Test func staleSecondReadDoesNotOverwriteAfterEarlierRead() async {
        let spy = SpyScanSimulator(
            scriptedOutcome: .findsCandidates(MedicineCandidate.demoCandidates)
        )
        let delay = ControllableReadDelay()
        let session = makeTestSession(simulator: spy, readDelay: delay)

        #expect(session.startCompanion())
        session.beginMedicineRead()
        await delay.waitForInstall()
        #expect(delay.release())
        if let task = session.pendingReadTask { await task.value }
        #expect(spy.outcomeCalls == [1])

        session.retakeMedicinePhoto()
        await delay.waitForInstall()
        let staleRead = session.pendingReadTask
        session.chooseFromFrequentList()
        session.confirmMedicine(MedicineCandidate.demoFrequentlyUsed[0])

        #expect(delay.release())
        if let staleRead { await staleRead.value }

        #expect(spy.outcomeCalls == [1])
        #expect(session.assessmentGate != nil)
    }

    @Test func staleAssessmentCannotOverwriteReconsideredChoice() async {
        let runner = ControllableMedicineAssessmentRunner()
        let session = makeTestSession(
            assessmentRunner: runner,
            requestIDs: [medicineTestUUID(40)]
        )
        Self.enterAssessmentFromFrequentList(session)
        await runner.waitForAssessmentCount(1)
        let staleTask = session.pendingAssessmentTask

        session.reconsiderMedicineChoice()
        #expect(runner.resolve(
            requestID: medicineTestUUID(40),
            with: makeMedicineResultState(requestID: medicineTestUUID(40))
        ))
        if let staleTask { await staleTask.value }

        guard case let .awaitingMedicineConfirmation(prompt) = session.state
        else {
            Issue.record("stale assessment replaced reconsidered state")
            return
        }
        #expect(prompt.origin == .chosenFromFrequentList)
    }

    @Test func cancelledAssessmentWritesNoSuccessRecord() async {
        let runner = ControllableMedicineAssessmentRunner()
        let store = RecordingCareRecordStore()
        let session = makeTestSession(
            records: store,
            assessmentRunner: runner,
            requestIDs: [medicineTestUUID(41)]
        )
        Self.enterAssessmentFromFrequentList(session)
        await runner.waitForAssessmentCount(1)
        let staleTask = session.pendingAssessmentTask

        session.endEarly()
        #expect(runner.resolve(
            requestID: medicineTestUUID(41),
            with: makeMedicineResultState(requestID: medicineTestUUID(41))
        ))
        if let staleTask { await staleTask.value }

        #expect(session.state == .completed(.endedEarly))
        #expect(Self.careActionCount(store) == 0)
    }

    @Test func newerAssessmentRejectsStaleEarlierResult() async {
        let runner = ControllableMedicineAssessmentRunner()
        let store = RecordingCareRecordStore()
        let firstID = medicineTestUUID(42)
        let secondID = medicineTestUUID(43)
        let session = makeTestSession(
            records: store,
            assessmentRunner: runner,
            requestIDs: [firstID, secondID]
        )

        Self.enterAssessmentFromFrequentList(session)
        await runner.waitForAssessmentCount(1)
        let firstTask = session.pendingAssessmentTask
        session.reconsiderMedicineChoice()
        session.confirmMedicine(MedicineCandidate.demoFrequentlyUsed[1])
        await runner.waitForAssessmentCount(2)
        let secondTask = session.pendingAssessmentTask

        #expect(runner.resolve(
            requestID: firstID,
            with: makeMedicineResultState(requestID: firstID)
        ))
        if let firstTask { await firstTask.value }
        #expect(session.canContinueAfterAssessment == false)

        #expect(runner.resolve(
            requestID: secondID,
            with: makeMedicineResultState(requestID: secondID)
        ))
        if let secondTask { await secondTask.value }
        #expect(session.canContinueAfterAssessment)
        #expect(Self.careActionCount(store) == 0)
    }

    @Test func repeatedConfirmationWritesOneRecord() async {
        let runner = ControllableMedicineAssessmentRunner()
        let store = RecordingCareRecordStore()
        let requestID = medicineTestUUID(44)
        let session = makeTestSession(
            records: store,
            assessmentRunner: runner,
            requestIDs: [requestID]
        )

        #expect(session.startCompanion())
        session.beginMedicineRead()
        session.chooseFromFrequentList()
        let candidate = MedicineCandidate.demoFrequentlyUsed[0]
        session.confirmMedicine(candidate)
        session.confirmMedicine(candidate)
        session.confirmMedicine(candidate)
        await runner.waitForAssessmentCount(1)
        let task = session.pendingAssessmentTask

        let confirmations = store.kinds.filter {
            if case .medicineConfirmed = $0 { return true }
            return false
        }
        #expect(confirmations.count == 1)
        #expect(runner.assessCalls.count == 1)

        #expect(runner.resolve(
            requestID: requestID,
            with: .cancelled
        ))
        if let task { await task.value }
    }

    private static func enterAssessmentFromFrequentList(
        _ session: CompanionSessionModel
    ) {
        #expect(session.startCompanion())
        session.beginMedicineRead()
        session.chooseFromFrequentList()
        session.confirmMedicine(MedicineCandidate.demoFrequentlyUsed[0])
    }

    private static func careActionCount(
        _ store: RecordingCareRecordStore
    ) -> Int {
        store.kinds.filter {
            if case .careActionShown = $0 { return true }
            return false
        }.count
    }
}
