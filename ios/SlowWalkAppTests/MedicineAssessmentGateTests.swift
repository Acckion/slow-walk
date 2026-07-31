import Foundation
import SlowWalkClientCore
import Testing
@testable import SlowWalkApp

@MainActor
struct MedicineAssessmentGateTests {
    @Test func confirmingOfferedCandidateEntersIdleCanonicalGate() {
        let prompt = Self.makePrompt()
        let candidate = MedicineCandidate.demoCandidates[0]

        let next = CompanionFlowReducer.nextState(
            from: .awaitingMedicineConfirmation(prompt),
            on: .confirmMedicine(candidate)
        )

        guard case let .awaitingMedicineAssessment(gate)? = next else {
            Issue.record("expected canonical assessment gate")
            return
        }
        #expect(gate.confirmed.candidate == candidate)
        #expect(gate.viewState == MedicineAssessmentViewState.idle)
        #expect(gate.hasFinalResult == false)
    }

    @Test func confirmingUnofferedCandidateIsRejected() {
        let prompt = Self.makePrompt()
        let forged = MedicineCandidate(
            id: "forged",
            displayName: "未提供的药品",
            recognitionHint: "不在当前列表"
        )
        #expect(
            CompanionFlowReducer.nextState(
                from: .awaitingMedicineConfirmation(prompt),
                on: .confirmMedicine(forged)
            ) == nil
        )
    }

    @Test func everyNonResultCanonicalStateRefusesProgression() {
        for viewState in Self.nonResultViewStates {
            let gate = Self.makeGate(viewState: viewState)
            #expect(
                CompanionFlowReducer.nextState(
                    from: .awaitingMedicineAssessment(gate),
                    on: .continueAfterMedicineAssessment(hasOuting: true)
                ) == nil,
                "non-result state advanced: \(viewState)"
            )
        }
    }

    @Test func resultCanAdvanceToTravellingWhenOutingExists() {
        let gate = Self.makeGate(viewState: makeMedicineResultState())
        #expect(
            CompanionFlowReducer.nextState(
                from: .awaitingMedicineAssessment(gate),
                on: .continueAfterMedicineAssessment(hasOuting: true)
            ) == .travelling
        )
    }

    @Test func medicineOnlyResultCompletesWithoutTravelling() {
        let gate = Self.makeGate(viewState: makeMedicineResultState())
        #expect(
            CompanionFlowReducer.nextState(
                from: .awaitingMedicineAssessment(gate),
                on: .continueAfterMedicineAssessment(hasOuting: false)
            ) == .completed(.medicineReviewCompleted)
        )
    }

    @Test func resultGenerationDoesNotWriteCareActionShown() async {
        let requestID = medicineTestUUID(20)
        let (session, store) = await Self.sessionAtResult(requestID: requestID)

        #expect(session.canContinueAfterAssessment)
        #expect(Self.careActionCount(in: store) == 0)
    }

    @Test func displayedResultWritesCareActionShown() async {
        let requestID = medicineTestUUID(21)
        let (session, store) = await Self.sessionAtResult(requestID: requestID)

        session.medicineActionCardDidAppear(requestID: requestID)

        #expect(Self.careActionCount(in: store) == 1)
    }

    @Test func repeatedDisplayIsIdempotent() async {
        let requestID = medicineTestUUID(22)
        let (session, store) = await Self.sessionAtResult(requestID: requestID)

        session.medicineActionCardDidAppear(requestID: requestID)
        session.medicineActionCardDidAppear(requestID: requestID)

        #expect(Self.careActionCount(in: store) == 1)
    }

    @Test func mismatchedResultRequestIDWritesNothing() async {
        let requestID = medicineTestUUID(23)
        let (session, store) = await Self.sessionAtResult(requestID: requestID)

        session.medicineActionCardDidAppear(requestID: medicineTestUUID(24))

        #expect(Self.careActionCount(in: store) == 0)
    }

    @Test func ambiguousStateHasNoFinalActionCardRecordOrProgression() async {
        let requestID = medicineTestUUID(25)
        let runner = ImmediateMedicineAssessmentRunner(
            assessHandler: { _, requestID in
                makeMedicineConfirmationState(requestID: requestID)
            }
        )
        let (session, store) = await Self.sessionAtAssessment(
            runner: runner,
            requestID: requestID
        )

        #expect(session.canContinueAfterAssessment == false)
        #expect(session.continueAfterMedicineAssessment() == false)
        session.medicineActionCardDidAppear(requestID: requestID)
        #expect(Self.careActionCount(in: store) == 0)
    }

    @Test func candidateMustComeFromCurrentResponse() async {
        let requestID = medicineTestUUID(26)
        let finalID = medicineTestUUID(27)
        let runner = ImmediateMedicineAssessmentRunner(
            assessHandler: { _, requestID in
                makeMedicineConfirmationState(requestID: requestID)
            },
            confirmationResult: makeMedicineResultState(requestID: finalID)
        )
        let (session, _) = await Self.sessionAtAssessment(
            runner: runner,
            requestID: requestID
        )

        session.confirmAssessmentCandidate(candidateID: "forged-candidate")
        #expect(session.pendingAssessmentTask == nil)
        #expect(runner.confirmedCandidateIDs.isEmpty)

        session.confirmAssessmentCandidate(candidateID: "demo-metformin")
        guard let task = session.pendingAssessmentTask else {
            Issue.record("candidate confirmation task was not started")
            return
        }
        await task.value
        #expect(runner.confirmedCandidateIDs == ["demo-metformin"])
    }

    @Test func serverConfirmationDoesNotOfferCandidateCommand() async {
        let requestID = medicineTestUUID(30)
        let runner = ImmediateMedicineAssessmentRunner(
            assessHandler: { _, requestID in
                makeServerMedicineConfirmationState(requestID: requestID)
            }
        )
        let (session, _) = await Self.sessionAtAssessment(
            runner: runner,
            requestID: requestID
        )

        #expect(session.assessmentCandidates.isEmpty)
        session.confirmAssessmentCandidate(candidateID: "demo-metformin")
        #expect(session.pendingAssessmentTask == nil)
        #expect(runner.confirmedCandidateIDs.isEmpty)
    }

    @Test func deviceLocalRunnerProducesCanonicalResultWithoutServer() async {
        let requestID = medicineTestUUID(31)
        let store = RecordingCareRecordStore()
        let clock = AppFixedClock(fixedDate: medicineTestDate)
        let session = makeTestSession(
            records: store,
            simulator: SpyScanSimulator(
                scriptedOutcome: .findsCandidates([
                    MedicineCandidate.demoCandidates[0]
                ])
            ),
            assessmentRunner: LocalMedicineAssessmentRunner.demo(clock: clock),
            requestIDs: [requestID]
        )

        #expect(session.startCompanion())
        session.beginMedicineRead()
        if let task = session.pendingReadTask { await task.value }
        session.confirmMedicine(MedicineCandidate.demoCandidates[0])
        guard let task = session.pendingAssessmentTask else {
            Issue.record("device-local assessment task was not started")
            return
        }
        await task.value

        guard case let .result(presentation) = session.assessmentGate?.viewState
        else {
            Issue.record("device-local assessment did not produce a result")
            return
        }
        #expect(presentation.response.requestID == requestID)
        #expect(
            presentation.response.resolution.selectedMedicine?.id
                == "demo-metformin"
        )
        #expect(Self.careActionCount(in: store) == 0)
    }

    @Test func cancelledAssessmentWritesNoSuccessRecord() async {
        let runner = ImmediateMedicineAssessmentRunner(
            assessHandler: { _, _ in .cancelled }
        )
        let (session, store) = await Self.sessionAtAssessment(
            runner: runner,
            requestID: medicineTestUUID(28)
        )

        #expect(session.canContinueAfterAssessment == false)
        #expect(Self.careActionCount(in: store) == 0)
        #expect(store.kinds.contains(
            .medicineAssessmentDidNotSucceed(.assessmentNotCompleted)
        ))
    }

    @Test func medicineOnlySessionNeverEntersTravelling() async {
        let plan = TodayPlan(
            preferredName: "王阿姨",
            medicines: [],
            outing: nil
        )
        let (session, _) = await Self.sessionAtResult(
            requestID: medicineTestUUID(29),
            plan: plan
        )

        #expect(session.continueAfterMedicineAssessment())
        #expect(session.state == .completed(.medicineReviewCompleted))
        #expect(session.state != .travelling)
    }

    static let everyViewState: [MedicineAssessmentViewState] = [
        .idle,
        .recognizing(startedAt: medicineTestDate),
        makeMedicineConfirmationState(),
        .assessing(startedAt: medicineTestDate),
        makeMedicineResultState(),
        makeMedicineFailureState(),
        .cancelled,
    ]

    static let nonResultViewStates: [MedicineAssessmentViewState] = [
        .idle,
        .recognizing(startedAt: medicineTestDate),
        makeMedicineConfirmationState(),
        .assessing(startedAt: medicineTestDate),
        makeMedicineFailureState(),
        .cancelled,
    ]

    static let everyState: [CompanionFlowState] = [
        .notStarted,
        .preDepartureCheck,
        .scanningMedicine(.first),
        .scanningMedicine(.first.interrupted(by: .textNotLegible)),
        .awaitingMedicineConfirmation(makePrompt()),
    ] + everyViewState.map {
        .awaitingMedicineAssessment(makeGate(viewState: $0))
    } + [
        .travelling,
        .approachingStop,
        .completed(.arrivedSafely),
        .completed(.medicineReviewCompleted),
        .completed(.endedEarly),
    ]

    static let everyEvent: [CompanionFlowEvent] = [
        .startCompanion,
        .beginMedicineRead,
        .medicineReadDidNotSucceed(.textNotLegible),
        .medicineReadDidNotSucceed(.noMedicineNameFound),
        .retryMedicineRead,
        .chooseFromFrequentList(MedicineCandidate.demoFrequentlyUsed),
        .medicineCandidatesReady(MedicineCandidate.demoCandidates),
        .retakeMedicinePhoto,
        .confirmMedicine(MedicineCandidate.demoCandidates[0]),
    ] + everyViewState.map {
        .medicineAssessmentUpdated($0)
    } + [
        .reconsiderMedicineChoice,
        .continueAfterMedicineAssessment(hasOuting: true),
        .continueAfterMedicineAssessment(hasOuting: false),
        .approachStop,
        .arriveSafely,
        .endEarly,
    ]

    static func makePrompt() -> MedicineConfirmationPrompt {
        MedicineConfirmationPrompt(
            candidates: MedicineCandidate.demoCandidates,
            origin: .readFromPhoto,
            attemptNumber: 1
        )
    }

    static func makeGate(
        viewState: MedicineAssessmentViewState
    ) -> MedicineAssessmentGate {
        MedicineAssessmentGate(
            confirmed: ConfirmedMedicine(
                candidate: MedicineCandidate.demoCandidates[0],
                origin: .readFromPhoto
            ),
            prompt: makePrompt(),
            viewState: viewState
        )
    }

    private static func sessionAtResult(
        requestID: UUID,
        plan: TodayPlan = .demo
    ) async -> (CompanionSessionModel, RecordingCareRecordStore) {
        await sessionAtAssessment(
            runner: ImmediateMedicineAssessmentRunner(
                assessHandler: { _, requestID in
                    makeMedicineResultState(requestID: requestID)
                }
            ),
            requestID: requestID,
            plan: plan
        )
    }

    private static func sessionAtAssessment(
        runner: any MedicineAssessmentRunning,
        requestID: UUID,
        plan: TodayPlan = .demo
    ) async -> (CompanionSessionModel, RecordingCareRecordStore) {
        let store = RecordingCareRecordStore()
        let delay = ControllableReadDelay()
        let session = makeTestSession(
            records: store,
            simulator: SpyScanSimulator(
                scriptedOutcome: .findsCandidates(
                    MedicineCandidate.demoCandidates
                )
            ),
            plan: plan,
            readDelay: delay,
            assessmentRunner: runner,
            requestIDs: [requestID]
        )

        #expect(session.startCompanion())
        session.beginMedicineRead()
        await delay.waitForInstall()
        #expect(delay.release())
        if let task = session.pendingReadTask { await task.value }
        session.confirmMedicine(MedicineCandidate.demoCandidates[0])
        guard let task = session.pendingAssessmentTask else {
            Issue.record("assessment task was not started")
            return (session, store)
        }
        await task.value
        return (session, store)
    }

    private static func careActionCount(
        in store: RecordingCareRecordStore
    ) -> Int {
        store.kinds.filter {
            if case .careActionShown = $0 { return true }
            return false
        }.count
    }
}
