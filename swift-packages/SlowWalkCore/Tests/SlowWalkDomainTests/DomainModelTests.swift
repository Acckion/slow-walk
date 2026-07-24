import Foundation
import SlowWalkDomain
import XCTest

final class DomainModelTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_735_689_600)

    func testRiskLevelsHaveStableRawValuesAndSeverityOrder() {
        XCTAssertEqual(
            RiskLevel.allCases.map(\.rawValue),
            ["green", "yellow", "orange", "red"]
        )
        XCTAssertLessThan(RiskLevel.green, .yellow)
        XCTAssertLessThan(RiskLevel.yellow, .orange)
        XCTAssertLessThan(RiskLevel.orange, .red)
    }

    func testEvidenceCompletenessHasStableOrder() {
        XCTAssertLessThan(EvidenceCompleteness.insufficient, .partial)
        XCTAssertLessThan(EvidenceCompleteness.partial, .complete)
    }

    func testAllCrossLayerModelsRoundTripThroughCodable() throws {
        let source = SourceReference(
            sourceName: "Demo Source",
            documentTitle: "DEMO DATA - NOT FOR CLINICAL USE",
            optionalURL: URL(string: "https://example.invalid/demo"),
            retrievedAt: timestamp,
            versionOrDate: "demo-v1"
        )
        let medicine = Medicine(
            id: "medicine-a",
            canonicalName: "Demo Medicine",
            aliases: ["Demo Alias"],
            activeIngredientIDs: ["ingredient-a"],
            medicineCategory: .other,
            sourceReferences: [source],
            dosageTextFromSource: nil,
            contraindicationTags: ["allergy-a"]
        )
        let profile = UserHealthProfile(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            age: 70,
            allergies: ["allergy-a"],
            diagnosedConditions: ["demo-condition"],
            currentMedicineIngredientIDs: ["ingredient-b"],
            bodyMetrics: BodyMetrics(
                systolicBloodPressure: 120,
                diastolicBloodPressure: 80,
                heartRate: 70,
                measuredAt: timestamp
            ),
            updatedAt: timestamp
        )
        let record = MedicationRecord(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            medicineID: medicine.id,
            activeIngredientIDs: medicine.activeIngredientIDs,
            recordedAt: timestamp,
            eventType: .taken,
            source: .manualEntry
        )
        let scan = MedicineScanEvent(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)),
            recognizedText: medicine.canonicalName,
            candidateMedicineID: medicine.id,
            confidence: 0.99,
            scannedAt: timestamp,
            recognitionStatus: .recognized
        )
        let assessment = RiskAssessment(
            level: .yellow,
            reasons: [
                RiskReason(
                    code: .missingEvidence,
                    message: "More information is needed.",
                    evidence: "Demo evidence.",
                    ruleIdentifier: "demo-rule"
                ),
            ],
            recommendedActions: [.consultHealthcareProfessional],
            assessedAt: timestamp,
            requiresProfessionalAdvice: true,
            requiresFamilyAttention: false,
            evidenceCompleteness: .partial
        )
        let original = DomainEnvelope(
            medicine: medicine,
            profile: profile,
            record: record,
            scan: scan,
            assessment: assessment
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DomainEnvelope.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testHashableModelsHaveValueSemantics() {
        let reason = RiskReason(
            code: .recognitionFailed,
            message: "Confirm the medicine.",
            evidence: "Recognition failed.",
            ruleIdentifier: "recognition-failure"
        )

        XCTAssertEqual(Set([reason, reason]).count, 1)
    }

    func testMedicineResolutionEnumsHaveStableRawValues() {
        XCTAssertEqual(
            MedicineResolutionStatus.allCases.map(\.rawValue),
            [
                "resolved",
                "ambiguous",
                "insufficient_evidence",
                "not_found",
                "recognition_failed",
            ]
        )
        XCTAssertEqual(
            MedicineResolutionCacheStatus.allCases.map(\.rawValue),
            ["hit", "miss", "expired", "source_version_changed"]
        )
    }

    func testLegacyMedicineJSONReceivesSafeMetadataDefaults() throws {
        let data = Data(
            """
            {
              "id": "legacy",
              "canonicalName": "Legacy Demo",
              "aliases": [],
              "activeIngredientIDs": ["legacy-ingredient"],
              "medicineCategory": "other",
              "sourceReferences": [],
              "dosageTextFromSource": null,
              "contraindicationTags": []
            }
            """.utf8
        )

        let medicine = try JSONDecoder().decode(Medicine.self, from: data)

        XCTAssertEqual(medicine.warnings, [])
        XCTAssertEqual(medicine.dataVersion, "legacy-v1")
        XCTAssertNil(medicine.dosageTextFromSource)
    }

    func testMedicinePipelineModelsRoundTripThroughCodable() throws {
        let medicine = Medicine(
            id: "medicine-demo",
            canonicalName: "Demo Medicine",
            aliases: ["Demo Alias"],
            activeIngredientIDs: ["demo-ingredient"],
            medicineCategory: .other,
            sourceReferences: [],
            dosageTextFromSource: nil,
            contraindicationTags: [],
            warnings: ["DEMO DATA — NOT FOR CLINICAL USE"],
            dataVersion: "demo-v2"
        )
        let recognition = MedicineRecognitionInput(
            recognizedTexts: ["Demo Medicine", "TABLETS 500 MG"],
            capturedAt: timestamp,
            languageCode: "en",
            rawConfidence: 0.98
        )
        let evidence = MedicineResolutionEvidence(
            recognizedTexts: recognition.recognizedTexts,
            normalizedText: "demo medicine tablets",
            normalizedQuery: "demo medicine",
            languageCode: recognition.languageCode,
            rawConfidence: recognition.rawConfidence,
            dosageForms: ["tablets"],
            removedSpecifications: ["500 mg"],
            discardedNoise: [],
            matcherVersion: "resolver-v1",
            sourceDataVersions: [medicine.dataVersion]
        )
        let candidate = MedicineCandidate(
            medicine: medicine,
            matchScore: 1,
            matchedAlias: nil,
            matchReasons: [.canonicalExact]
        )
        let resolution = MedicineResolution(
            status: .resolved,
            candidates: [candidate],
            selectedMedicine: medicine,
            evidence: evidence,
            requiresUserConfirmation: false
        )
        let card = ActionCard(
            title: "Medicine confirmed",
            primaryInstruction: "Follow only verified source information.",
            warnings: medicine.warnings,
            recommendedActions: [.followVerifiedSourceInformation],
            riskLevel: .green,
            sourceReferences: [],
            mustConfirmMedicine: false,
            generatedAt: timestamp
        )
        let original = MedicinePipelineEnvelope(
            recognition: recognition,
            resolution: resolution,
            actionCard: card
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            MedicinePipelineEnvelope.self,
            from: data
        )

        XCTAssertEqual(decoded, original)
    }
}

private struct DomainEnvelope: Codable, Equatable {
    let medicine: Medicine
    let profile: UserHealthProfile
    let record: MedicationRecord
    let scan: MedicineScanEvent
    let assessment: RiskAssessment
}

private struct MedicinePipelineEnvelope: Codable, Equatable {
    let recognition: MedicineRecognitionInput
    let resolution: MedicineResolution
    let actionCard: ActionCard
}
