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
}

private struct DomainEnvelope: Codable, Equatable {
    let medicine: Medicine
    let profile: UserHealthProfile
    let record: MedicationRecord
    let scan: MedicineScanEvent
    let assessment: RiskAssessment
}
