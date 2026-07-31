import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
@testable import SlowWalkApp

let medicineTestDate = Date(timeIntervalSince1970: 1_753_000_000)

func medicineTestUUID(_ value: UInt8) -> UUID {
    UUID(
        uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, value
        )
    )
}

func makeMedicineTestResponse(
    requestID: UUID = medicineTestUUID(1),
    riskLevel: RiskLevel = .green,
    medicineID: String = "demo-metformin",
    medicineName: String = "二甲双胍",
    requiresMedicineConfirmation: Bool = false
) -> MedicineAssessmentResponseDTO {
    let source = SourceReference(
        sourceName: "SlowWalk demo catalog",
        documentTitle: "DEMO DATA - NOT FOR CLINICAL USE",
        optionalURL: nil,
        retrievedAt: medicineTestDate,
        versionOrDate: "demo-v1"
    )
    let medicine = Medicine(
        id: medicineID,
        canonicalName: medicineName,
        aliases: [],
        activeIngredientIDs: [medicineID],
        medicineCategory: .other,
        sourceReferences: [source],
        dosageTextFromSource: nil,
        contraindicationTags: [],
        warnings: ["DEMO DATA - NOT FOR CLINICAL USE"],
        dataVersion: "demo-v1"
    )
    let candidate = SlowWalkDomain.MedicineCandidate(
        medicine: medicine,
        matchScore: 1,
        matchedAlias: nil,
        matchReasons: [.canonicalExact]
    )
    let assessment = RiskAssessment(
        level: riskLevel,
        reasons: [],
        recommendedActions: [.followVerifiedSourceInformation],
        assessedAt: medicineTestDate,
        requiresProfessionalAdvice: false,
        requiresFamilyAttention: false,
        evidenceCompleteness: .complete
    )
    let actionCard = ActionCard(
        title: "查看用药提示",
        primaryInstruction: "请核对药盒和可信来源。",
        warnings: ["DEMO DATA - NOT FOR CLINICAL USE"],
        recommendedActions: [.followVerifiedSourceInformation],
        riskLevel: riskLevel,
        sourceReferences: [source],
        mustConfirmMedicine: requiresMedicineConfirmation,
        generatedAt: medicineTestDate
    )
    return MedicineAssessmentResponseDTO(
        requestID: requestID,
        resolution: MedicineResolution(
            status: .resolved,
            candidates: [candidate],
            selectedMedicine: medicine,
            evidence: makeMedicineTestEvidence(name: medicineName),
            requiresUserConfirmation: requiresMedicineConfirmation
        ),
        assessment: assessment,
        actionCard: actionCard,
        cacheHit: false,
        resolutionCacheStatus: .miss,
        sourceDataVersion: "demo-v1",
        generatedAt: medicineTestDate,
        apiVersion: SlowWalkAPI.version
    )
}

func makeServerMedicineConfirmationState(
    requestID: UUID = medicineTestUUID(3)
) -> MedicineAssessmentViewState {
    let response = makeMedicineTestResponse(
        requestID: requestID,
        requiresMedicineConfirmation: true
    )
    return .requiresMedicineConfirmation(
        MedicineConfirmationRequirement(
            reason: .serverRequiresConfirmation,
            recognitionInput: MedicineRecognitionInput(
                recognizedTexts: ["二甲双胍"],
                capturedAt: medicineTestDate,
                languageCode: "zh-Hans",
                rawConfidence: 0.98
            ),
            response: response
        )
    )
}

func makeMedicineConfirmationState(
    requestID: UUID = medicineTestUUID(2),
    candidates: [(id: String, name: String)] = [
        ("demo-metformin", "二甲双胍"),
        ("demo-amlodipine", "氨氯地平"),
    ]
) -> MedicineAssessmentViewState {
    let medicines = candidates.map { item -> Medicine in
        Medicine(
            id: item.id,
            canonicalName: item.name,
            aliases: [],
            activeIngredientIDs: [item.id],
            medicineCategory: .other,
            sourceReferences: [],
            dosageTextFromSource: nil,
            contraindicationTags: [],
            dataVersion: "demo-v1"
        )
    }
    let domainCandidates = medicines.map {
        SlowWalkDomain.MedicineCandidate(
            medicine: $0,
            matchScore: 0.8,
            matchedAlias: nil,
            matchReasons: [.canonicalNormalized]
        )
    }
    let response = MedicineAssessmentResponseDTO(
        requestID: requestID,
        resolution: MedicineResolution(
            status: .ambiguous,
            candidates: domainCandidates,
            selectedMedicine: nil,
            evidence: makeMedicineTestEvidence(name: "演示候选"),
            requiresUserConfirmation: true
        ),
        assessment: nil,
        actionCard: ActionCard(
            title: "需要确认药品",
            primaryInstruction: "请先确认药品身份。",
            warnings: [],
            recommendedActions: [.doNotTakeUntilMedicineConfirmed],
            riskLevel: .yellow,
            sourceReferences: [],
            mustConfirmMedicine: true,
            generatedAt: medicineTestDate
        ),
        cacheHit: false,
        resolutionCacheStatus: .miss,
        sourceDataVersion: "demo-v1",
        generatedAt: medicineTestDate,
        apiVersion: SlowWalkAPI.version
    )
    return .requiresMedicineConfirmation(
        MedicineConfirmationRequirement(
            reason: .ambiguousMedicine,
            recognitionInput: MedicineRecognitionInput(
                recognizedTexts: ["演示候选"],
                capturedAt: medicineTestDate,
                languageCode: "zh-Hans",
                rawConfidence: 0.8
            ),
            response: response
        )
    )
}

func makeMedicineResultState(
    requestID: UUID = medicineTestUUID(1),
    riskLevel: RiskLevel = .green
) -> MedicineAssessmentViewState {
    .result(
        MedicineAssessmentPresentation(
            response: makeMedicineTestResponse(
                requestID: requestID,
                riskLevel: riskLevel
            )
        )
    )
}

func makeMedicineFailureState(
    requestID: UUID? = nil,
    recoverable: Bool = true
) -> MedicineAssessmentViewState {
    .failed(
        ClientFailure(
            kind: .timeout,
            apiErrorCode: .knowledgeSourceTimeout,
            requestID: requestID,
            endpoint: .medicineAssess,
            isRecoverable: recoverable
        )
    )
}

private func makeMedicineTestEvidence(
    name: String
) -> MedicineResolutionEvidence {
    MedicineResolutionEvidence(
        recognizedTexts: [name],
        normalizedText: name,
        normalizedQuery: name,
        languageCode: "zh-Hans",
        rawConfidence: 0.98,
        dosageForms: [],
        removedSpecifications: [],
        discardedNoise: [],
        matcherVersion: "test-v1",
        sourceDataVersions: ["demo-v1"]
    )
}

@MainActor
final class ImmediateMedicineAssessmentRunner: MedicineAssessmentRunning {
    typealias AssessHandler =
        (AppMedicineCandidate, UUID) -> MedicineAssessmentViewState

    var assessHandler: AssessHandler
    var confirmationResult: MedicineAssessmentViewState

    private(set) var assessedRequestIDs: [UUID] = []
    private(set) var confirmedCandidateIDs: [String] = []
    private(set) var cancellationCount = 0

    init(
        assessHandler: @escaping AssessHandler = { _, requestID in
            makeMedicineResultState(requestID: requestID)
        },
        confirmationResult: MedicineAssessmentViewState =
            makeMedicineResultState()
    ) {
        self.assessHandler = assessHandler
        self.confirmationResult = confirmationResult
    }

    func assess(
        medicine: AppMedicineCandidate,
        requestID: UUID
    ) async -> MedicineAssessmentViewState {
        assessedRequestIDs.append(requestID)
        return assessHandler(medicine, requestID)
    }

    func confirmMedicine(
        candidateID: String
    ) async -> MedicineAssessmentViewState {
        confirmedCandidateIDs.append(candidateID)
        return confirmationResult
    }

    func cancelCurrentAssessment() async {
        cancellationCount += 1
    }
}

@MainActor
final class ControllableMedicineAssessmentRunner: MedicineAssessmentRunning {
    struct AssessCall: Equatable {
        let medicine: AppMedicineCandidate
        let requestID: UUID
    }

    private(set) var assessCalls: [AssessCall] = []
    private(set) var confirmedCandidateIDs: [String] = []
    private var parkedAssessments: [UUID:
        CheckedContinuation<MedicineAssessmentViewState, Never>] = [:]

    func assess(
        medicine: AppMedicineCandidate,
        requestID: UUID
    ) async -> MedicineAssessmentViewState {
        assessCalls.append(AssessCall(medicine: medicine, requestID: requestID))
        return await withCheckedContinuation { continuation in
            parkedAssessments[requestID] = continuation
        }
    }

    func confirmMedicine(
        candidateID: String
    ) async -> MedicineAssessmentViewState {
        confirmedCandidateIDs.append(candidateID)
        return .cancelled
    }

    func cancelCurrentAssessment() async {}

    func waitForAssessmentCount(_ count: Int) async {
        while assessCalls.count < count {
            await Task.yield()
        }
    }

    @discardableResult
    func resolve(
        requestID: UUID,
        with state: MedicineAssessmentViewState
    ) -> Bool {
        guard let continuation = parkedAssessments.removeValue(
            forKey: requestID
        ) else {
            return false
        }
        continuation.resume(returning: state)
        return true
    }
}

@MainActor
struct ImmediateMedicineReadDelay: MedicineReadDelaying {
    func wait() async throws {}
}

@MainActor
func makeTestSession(
    records: RecordingCareRecordStore = RecordingCareRecordStore(),
    simulator: SpyScanSimulator = SpyScanSimulator(),
    plan: TodayPlan = .demo,
    readDelay: any MedicineReadDelaying = ImmediateMedicineReadDelay(),
    assessmentRunner: any MedicineAssessmentRunning =
        ImmediateMedicineAssessmentRunner(),
    requestIDs: [UUID] = [medicineTestUUID(10)]
) -> CompanionSessionModel {
    var remainingRequestIDs = requestIDs
    return CompanionSessionModel(
        records: records,
        simulator: simulator,
        plan: plan,
        readDelay: readDelay,
        assessmentRunner: assessmentRunner,
        clock: AppFixedClock(fixedDate: medicineTestDate),
        capabilities: .phase0,
        makeRequestID: {
            if remainingRequestIDs.isEmpty {
                return medicineTestUUID(255)
            }
            return remainingRequestIDs.removeFirst()
        }
    )
}

extension CompanionSessionModel {
    /// Keeps pre-existing read/capability tests focused on their original seam.
    /// Canonical assessment tests inject an explicit runner through the full
    /// production initializer or `makeTestSession`.
    convenience init(
        records: any CareRecordStoring,
        simulator: any MedicineScanSimulating,
        plan: TodayPlan,
        readDelay: any MedicineReadDelaying,
        capabilities: CapabilityCatalog
    ) {
        self.init(
            records: records,
            simulator: simulator,
            plan: plan,
            readDelay: readDelay,
            assessmentRunner: ImmediateMedicineAssessmentRunner(),
            clock: AppFixedClock(fixedDate: medicineTestDate),
            capabilities: capabilities,
            makeRequestID: { medicineTestUUID(10) }
        )
    }
}
