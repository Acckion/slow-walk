import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
import XCTest

final class MedicinePipelineDTOTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_753_315_200)

    func testResolutionDTOsRoundTripWithCanonicalJSONCoding() throws {
        let input = makeRecognitionInput()
        let request = MedicineResolutionRequestDTO(
            input: input,
            requestID: fixedUUID(lastByte: 1),
            apiVersion: SlowWalkAPI.version
        )
        let response = MedicineResolutionResponseDTO(
            requestID: request.requestID,
            resolution: makeResolution(input: input),
            cacheHit: false,
            resolutionCacheStatus: .miss,
            sourceDataVersion: "demo-2026-07-24",
            generatedAt: now,
            apiVersion: SlowWalkAPI.version
        )
        let original = ResolutionEnvelope(request: request, response: response)

        let data = try SlowWalkJSONCoding.makeEncoder().encode(original)
        let decoded = try SlowWalkJSONCoding.makeDecoder().decode(
            ResolutionEnvelope.self,
            from: data
        )

        XCTAssertEqual(decoded, original)
    }

    func testAssessmentDTOsRoundTripWithoutUntypedPayloads() throws {
        let input = makeRecognitionInput()
        let profile = UserHealthProfile(
            id: fixedUUID(lastByte: 2),
            age: 70,
            allergies: [],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: nil,
            updatedAt: now
        )
        let request = MedicineAssessmentRequestDTO(
            input: input,
            userProfile: UserHealthProfileDTO(profile),
            recentRecords: [],
            requestID: fixedUUID(lastByte: 3),
            apiVersion: SlowWalkAPI.version
        )
        let resolution = makeResolution(input: input)
        let assessment = RiskAssessment(
            level: .yellow,
            reasons: [
                RiskReason(
                    code: .bodyMetricsMissing,
                    message: "Current body-metric context is unavailable.",
                    evidence: "No body metrics were supplied.",
                    ruleIdentifier: "body-metrics-data-quality"
                ),
            ],
            recommendedActions: [.remeasureBodyMetrics],
            assessedAt: now,
            requiresProfessionalAdvice: false,
            requiresFamilyAttention: false,
            evidenceCompleteness: .partial
        )
        let actionCard = ActionCard(
            title: "Review before use",
            primaryInstruction: "Review the warnings before deciding what to do.",
            warnings: ["DEMO DATA — NOT FOR CLINICAL USE"],
            recommendedActions: assessment.recommendedActions,
            riskLevel: assessment.level,
            sourceReferences: resolution.selectedMedicine?.sourceReferences ?? [],
            mustConfirmMedicine: false,
            generatedAt: now
        )
        let response = MedicineAssessmentResponseDTO(
            requestID: request.requestID,
            resolution: resolution,
            assessment: assessment,
            actionCard: actionCard,
            cacheHit: true,
            resolutionCacheStatus: .hit,
            knowledgeCacheStatus: nil,
            sourceDataVersion: "demo-2026-07-24",
            generatedAt: now,
            apiVersion: SlowWalkAPI.version
        )
        let original = AssessmentEnvelope(request: request, response: response)

        let data = try SlowWalkJSONCoding.makeEncoder().encode(original)
        let decoded = try SlowWalkJSONCoding.makeDecoder().decode(
            AssessmentEnvelope.self,
            from: data
        )

        XCTAssertEqual(decoded, original)
    }

    private func makeRecognitionInput() -> MedicineRecognitionInput {
        MedicineRecognitionInput(
            recognizedTexts: ["Demo Medicine", "TABLETS"],
            capturedAt: now,
            languageCode: "en",
            rawConfidence: 0.98
        )
    }

    private func makeResolution(
        input: MedicineRecognitionInput
    ) -> MedicineResolution {
        let source = SourceReference(
            sourceName: "SlowWalk demo catalog",
            documentTitle: "DEMO DATA — NOT FOR CLINICAL USE",
            optionalURL: nil,
            retrievedAt: now,
            versionOrDate: "demo-2026-07-24"
        )
        let medicine = Medicine(
            id: "demo-medicine",
            canonicalName: "Demo Medicine",
            aliases: ["Demo Alias"],
            activeIngredientIDs: ["demo-ingredient"],
            medicineCategory: .other,
            sourceReferences: [source],
            dosageTextFromSource: nil,
            contraindicationTags: [],
            warnings: ["DEMO DATA — NOT FOR CLINICAL USE"],
            dataVersion: "demo-2026-07-24"
        )
        let candidate = MedicineCandidate(
            medicine: medicine,
            matchScore: 1,
            matchedAlias: nil,
            matchReasons: [.canonicalExact]
        )
        let evidence = MedicineResolutionEvidence(
            recognizedTexts: input.recognizedTexts,
            normalizedText: "demo medicine tablets",
            normalizedQuery: "demo medicine",
            languageCode: input.languageCode,
            rawConfidence: input.rawConfidence,
            dosageForms: ["tablets"],
            removedSpecifications: [],
            discardedNoise: [],
            matcherVersion: "resolver-v1",
            sourceDataVersions: [medicine.dataVersion]
        )
        return MedicineResolution(
            status: .resolved,
            candidates: [candidate],
            selectedMedicine: medicine,
            evidence: evidence,
            requiresUserConfirmation: false
        )
    }

    private func fixedUUID(lastByte: UInt8) -> UUID {
        UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, lastByte)
        )
    }
}

private struct ResolutionEnvelope: Codable, Equatable {
    let request: MedicineResolutionRequestDTO
    let response: MedicineResolutionResponseDTO
}

private struct AssessmentEnvelope: Codable, Equatable {
    let request: MedicineAssessmentRequestDTO
    let response: MedicineAssessmentResponseDTO
}
