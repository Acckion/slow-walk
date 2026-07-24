import Foundation
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicinePipeline
import SlowWalkRiskEngine

let pipelineTestDate = Date(timeIntervalSince1970: 1_753_315_200)
let pipelineTestUUID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 42)
)

func makeRecognitionInput(
    _ texts: [String],
    confidence: Double? = 0.98,
    capturedAt: Date = pipelineTestDate
) -> MedicineRecognitionInput {
    MedicineRecognitionInput(
        recognizedTexts: texts,
        capturedAt: capturedAt,
        languageCode: "en",
        rawConfidence: confidence
    )
}

func loadDemoCatalog() throws -> MedicineCatalog {
    try BundledDemoMedicineCatalogLoader().loadCatalog()
}

func makePipelineProfile(
    allergies: [String] = []
) -> UserHealthProfile {
    UserHealthProfile(
        id: UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 7
            )
        ),
        age: 70,
        allergies: allergies,
        diagnosedConditions: [],
        currentMedicineIngredientIDs: [],
        bodyMetrics: BodyMetrics(
            systolicBloodPressure: 120,
            diastolicBloodPressure: 75,
            heartRate: 68,
            measuredAt: pipelineTestDate.addingTimeInterval(-60)
        ),
        updatedAt: pipelineTestDate.addingTimeInterval(-60)
    )
}

func makeResolutionEvidence(
    normalizedQuery: String = "acetaminophen",
    confidence: Double? = 0.98
) -> MedicineResolutionEvidence {
    MedicineResolutionEvidence(
        recognizedTexts: [normalizedQuery],
        normalizedText: normalizedQuery,
        normalizedQuery: normalizedQuery,
        languageCode: "en",
        rawConfidence: confidence,
        dosageForms: [],
        removedSpecifications: [],
        discardedNoise: [],
        matcherVersion: "test-matcher",
        sourceDataVersions: ["slowwalk-demo-catalog-v1"]
    )
}

func makeResolvedResolution(
    medicine: Medicine
) -> MedicineResolution {
    MedicineResolution(
        status: .resolved,
        candidates: [
            MedicineCandidate(
                medicine: medicine,
                matchScore: 1,
                matchedAlias: nil,
                matchReasons: [.canonicalExact]
            ),
        ],
        selectedMedicine: medicine,
        evidence: makeResolutionEvidence(),
        requiresUserConfirmation: false
    )
}

func makeUnresolvedResolution(
    status: MedicineResolutionStatus
) -> MedicineResolution {
    MedicineResolution(
        status: status,
        candidates: [],
        selectedMedicine: nil,
        evidence: makeResolutionEvidence(
            normalizedQuery: "",
            confidence: 0
        ),
        requiresUserConfirmation: true
    )
}

func makeAssessment(
    level: RiskLevel,
    actions: [RecommendedAction],
    completeness: EvidenceCompleteness = .complete
) -> RiskAssessment {
    RiskAssessment(
        level: level,
        reasons: [
            RiskReason(
                code: .missingEvidence,
                message: "Test warning.",
                evidence: "Test evidence.",
                ruleIdentifier: "test-rule"
            ),
        ],
        recommendedActions: actions,
        assessedAt: pipelineTestDate,
        requiresProfessionalAdvice: level >= .yellow,
        requiresFamilyAttention: level == .red,
        evidenceCompleteness: completeness
    )
}

func makePipeline(
    cache: any MedicineCache = InMemoryMedicineCache(),
    date: Date = pipelineTestDate
) -> MedicinePipeline {
    MedicinePipeline(
        catalogLoader: BundledDemoMedicineCatalogLoader(),
        cache: cache,
        dateProvider: FixedClock(fixedDate: date),
        uuidProvider: FixedUUIDProvider(
            fixedUUID: pipelineTestUUID
        )
    )
}
