import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
import SlowWalkLocationRisk

let clientTestDate = Date(
    timeIntervalSince1970: 1_784_980_800
)

func clientTestUUID(_ byte: UInt8) -> UUID {
    UUID(
        uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, byte
        )
    )
}

struct FixedClientClock: Clock {
    let date: Date

    func now() -> Date {
        date
    }
}

func makeClientProfile() -> UserHealthProfileDTO {
    UserHealthProfileDTO(
        id: clientTestUUID(1),
        age: 70,
        allergies: [],
        diagnosedConditions: [],
        currentMedicineIngredientIDs: [],
        bodyMetrics: nil,
        createdAt: clientTestDate,
        updatedAt: clientTestDate,
        schemaVersion: 1
    )
}

func makeOCRImageInput() -> OCRImageInput {
    OCRImageInput(
        data: Data([1, 2, 3]),
        orientation: .up,
        capturedAt:
            clientTestDate.addingTimeInterval(-10)
    )
}

func makeObservation(
    text: String = "Demo Medicine",
    confidence: Double = 0.95,
    x: Double? = 0,
    y: Double? = 0,
    languageCode: String? = "en",
    observedAt: Date = clientTestDate
) -> RecognizedTextObservation {
    RecognizedTextObservation(
        text: text,
        confidence: confidence,
        boundingRegion: x.flatMap { x in
            y.map {
                OCRBoundingRegion(
                    x: x,
                    y: $0,
                    width: 0.3,
                    height: 0.1
                )
            }
        },
        languageCode: languageCode,
        observedAt: observedAt
    )
}

func makeRecognitionMapper(
    minimumConfidence: Double = 0.5,
    handling:
        LowConfidenceObservationHandling = .discard
) throws -> MedicineRecognitionInputMapper {
    MedicineRecognitionInputMapper(
        configuration:
            try MedicineRecognitionMappingConfiguration(
                minimumConfidence: minimumConfidence,
                lowConfidenceHandling: handling
            )
    )
}

func makeMedicineResponse(
    requestID: UUID = clientTestUUID(10),
    status: MedicineResolutionStatus = .resolved,
    riskLevel: RiskLevel = .yellow,
    requiresConfirmation: Bool = false,
    knowledgeWarning: Bool = false
) -> MedicineAssessmentResponseDTO {
    let source = SourceReference(
        sourceName: "SlowWalk demo catalog",
        documentTitle:
            "DEMO DATA — NOT FOR CLINICAL USE",
        optionalURL: nil,
        retrievedAt: clientTestDate,
        versionOrDate: "demo-v1"
    )
    let medicine = Medicine(
        id: "demo-medicine",
        canonicalName: "Demo Medicine",
        aliases: [],
        activeIngredientIDs: ["demo-ingredient"],
        medicineCategory: .other,
        sourceReferences: [source],
        dosageTextFromSource: nil,
        contraindicationTags: [],
        warnings: [
            "DEMO DATA — NOT FOR CLINICAL USE",
        ],
        dataVersion: "demo-v1"
    )
    let candidate = MedicineCandidate(
        medicine: medicine,
        matchScore: 1,
        matchedAlias: nil,
        matchReasons: [.canonicalExact]
    )
    let resolution = MedicineResolution(
        status: status,
        candidates:
            status == .resolved ? [candidate] : [],
        selectedMedicine:
            status == .resolved ? medicine : nil,
        evidence: MedicineResolutionEvidence(
            recognizedTexts: ["Demo Medicine"],
            normalizedText: "demo medicine",
            normalizedQuery: "demo medicine",
            languageCode: "en",
            rawConfidence: 0.95,
            dosageForms: [],
            removedSpecifications: [],
            discardedNoise: [],
            matcherVersion: "resolver-v1",
            sourceDataVersions: ["demo-v1"]
        ),
        requiresUserConfirmation:
            requiresConfirmation
    )
    let reason = RiskReason(
        code: knowledgeWarning
            ? .knowledgeSourceWarning
            : .missingEvidence,
        message: "Review available evidence.",
        evidence: "Demo evidence only.",
        ruleIdentifier: knowledgeWarning
            ? "knowledge-source-governance"
            : "missing-evidence"
    )
    let assessment: RiskAssessment? =
        status == .resolved
        ? RiskAssessment(
            level: riskLevel,
            reasons: [reason],
            recommendedActions: [
                .consultHealthcareProfessional,
            ],
            assessedAt: clientTestDate,
            requiresProfessionalAdvice:
                riskLevel >= .orange,
            requiresFamilyAttention:
                riskLevel == .red,
            evidenceCompleteness: .partial
        )
        : nil
    let warnings = knowledgeWarning
        ? [
            "DEMO DATA — NOT FOR CLINICAL USE",
            "Knowledge source requires review.",
        ]
        : ["DEMO DATA — NOT FOR CLINICAL USE"]
    let card = ActionCard(
        title: "Review before use",
        primaryInstruction:
            "Review the evidence before deciding.",
        warnings: warnings,
        recommendedActions: [
            .consultHealthcareProfessional,
        ],
        riskLevel: riskLevel,
        sourceReferences:
            status == .resolved ? [source] : [],
        mustConfirmMedicine:
            status != .resolved
                || requiresConfirmation,
        generatedAt: clientTestDate
    )
    return MedicineAssessmentResponseDTO(
        requestID: requestID,
        resolution: resolution,
        assessment: assessment,
        actionCard: card,
        cacheHit: false,
        resolutionCacheStatus: .miss,
        knowledgeCacheStatus: nil,
        sourceDataVersion: "demo-v1",
        generatedAt: clientTestDate,
        apiVersion: SlowWalkAPI.version,
        healthContextValidation: nil,
        medicineKnowledge: nil
    )
}

func makeDestination() -> Destination {
    Destination(
        id: "demo-destination",
        name: "虚构目的地",
        point: GeoPoint(
            latitude: 31.2304,
            longitude: 121.4737
        ),
        geofenceRadiusMeters: 50
    )
}

func makeLocationSample(
    offset: TimeInterval,
    latitudeDelta: Double = 0,
    accuracy: Double? = 10,
    source: String? = "demo"
) -> LocationSample {
    LocationSample(
        point: GeoPoint(
            latitude: 31.2304 + latitudeDelta,
            longitude: 121.4737
        ),
        recordedAt:
            clientTestDate.addingTimeInterval(offset),
        horizontalAccuracyMeters: accuracy,
        speedMetersPerSecond: 1,
        source: source
    )
}

func makeLocationResponse(
    requestID: UUID = clientTestUUID(20),
    level: RiskLevel = .green,
    reasonCode:
        LocationRiskReasonCode =
            .arrivedAtDestination,
    accuracy: LocationAccuracy = .excellent,
    qualityStatus:
        LocationDataQualityStatus = .valid
) -> LocationAssessmentResponseDTO {
    let quality = LocationDataQuality(
        status: qualityStatus,
        accuracy: accuracy,
        issues: [],
        usableSampleIndices: [0, 1],
        configurationNotices: []
    )
    let assessment = LocationAssessment(
        level: level,
        reasons: [
            LocationRiskReason(
                code: reasonCode,
                message: "Demo location result.",
                evidence: "Demo evidence only.",
                ruleIdentifier: "location-demo"
            ),
        ],
        recommendedActions:
            level == .red
            ? [.contactFamilyOrStaff]
            : [.confirmArrival],
        assessedAt: clientTestDate,
        dataQuality: quality,
        distanceToDestinationMeters: 10,
        isInsideDestinationGeofence:
            reasonCode == .arrivedAtDestination,
        requiresUserAttention: level >= .yellow,
        requiresFamilyAttention: level == .red
    )
    let card = LocationActionCard(
        title: "Location reminder",
        primaryInstruction:
            "Review the location evidence.",
        warnings: ["DEMO DATA"],
        recommendedActions:
            assessment.recommendedActions,
        riskLevel: level,
        distanceText: "10 m",
        generatedAt: clientTestDate
    )
    return LocationAssessmentResponseDTO(
        requestID: requestID,
        assessment: assessment,
        actionCard: card,
        warnings: card.warnings,
        generatedAt: clientTestDate,
        apiVersion: SlowWalkAPI.version
    )
}

actor CapturingMedicineRequester:
    MedicineAssessmentRequesting
{
    private(set) var request:
        MedicineAssessmentRequestDTO?
    let response: MedicineAssessmentResponseDTO

    init(response: MedicineAssessmentResponseDTO) {
        self.response = response
    }

    func assess(
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO {
        self.request = request
        return response
    }
}

actor CapturingLocationRequester:
    LocationAssessmentRequesting
{
    private(set) var request:
        LocationAssessmentRequestDTO?
    let response: LocationAssessmentResponseDTO

    init(response: LocationAssessmentResponseDTO) {
        self.response = response
    }

    func assess(
        request: LocationAssessmentRequestDTO
    ) async throws -> LocationAssessmentResponseDTO {
        self.request = request
        return response
    }
}

struct CancellableMedicineRequester:
    MedicineAssessmentRequesting
{
    func assess(
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO {
        try await Task<Never, Never>.sleep(
            nanoseconds: 60_000_000_000
        )
        throw ClientTransportError.unavailable
    }
}

struct CancellableLocationRequester:
    LocationAssessmentRequesting
{
    func assess(
        request: LocationAssessmentRequestDTO
    ) async throws -> LocationAssessmentResponseDTO {
        try await Task<Never, Never>.sleep(
            nanoseconds: 60_000_000_000
        )
        throw ClientTransportError.unavailable
    }
}
