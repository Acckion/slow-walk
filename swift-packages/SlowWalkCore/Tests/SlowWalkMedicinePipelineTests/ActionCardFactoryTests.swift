import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicinePipeline
import XCTest

final class ActionCardFactoryTests: XCTestCase {
    func testUnresolvedCardContainsThreeExplicitSafetyLayers() {
        let card = ActionCardFactory().makeCard(
            resolution: makeUnresolvedResolution(
                status: .recognitionFailed
            ),
            assessment: nil,
            generatedAt: pipelineTestDate
        )

        XCTAssertEqual(
            card.title,
            "Unable to confirm the medicine"
        )
        XCTAssertTrue(
            card.primaryInstruction.contains(
                "front of the medicine box"
            )
        )
        XCTAssertTrue(
            card.warnings.contains {
                $0.contains("Do not take")
            }
        )
        XCTAssertTrue(card.mustConfirmMedicine)
        XCTAssertEqual(card.riskLevel, .yellow)
    }

    func testUnresolvedCardNeverExposesCandidateSources() throws {
        let card = ActionCardFactory().makeCard(
            resolution: makeUnresolvedResolution(
                status: .ambiguous
            ),
            assessment: nil,
            generatedAt: pipelineTestDate
        )

        XCTAssertTrue(card.sourceReferences.isEmpty)
        XCTAssertFalse(
            card.recommendedActions.contains(
                .followVerifiedSourceInformation
            )
        )
    }

    func testRedCardAlwaysRemovesOrdinaryFollowSourceAction() throws {
        let medicine = try XCTUnwrap(
            loadDemoCatalog().medicines.first
        )
        let card = ActionCardFactory().makeCard(
            resolution: makeResolvedResolution(
                medicine: medicine
            ),
            assessment: makeAssessment(
                level: .red,
                actions: [
                    .followVerifiedSourceInformation,
                    .notifyFamilyMember,
                    .consultHealthcareProfessional,
                ]
            ),
            generatedAt: pipelineTestDate
        )

        XCTAssertEqual(card.riskLevel, .red)
        XCTAssertFalse(
            card.recommendedActions.contains(
                .followVerifiedSourceInformation
            )
        )
        XCTAssertTrue(
            card.recommendedActions.contains(.notifyFamilyMember)
        )
    }

    func testIncompleteGreenAssessmentIsDisplayedAsYellow() throws {
        let medicine = try XCTUnwrap(
            loadDemoCatalog().medicines.first
        )
        let card = ActionCardFactory().makeCard(
            resolution: makeResolvedResolution(
                medicine: medicine
            ),
            assessment: makeAssessment(
                level: .green,
                actions: [.followVerifiedSourceInformation],
                completeness: .partial
            ),
            generatedAt: pipelineTestDate
        )

        XCTAssertEqual(card.riskLevel, .yellow)
        XCTAssertFalse(
            card.recommendedActions.contains(
                .followVerifiedSourceInformation
            )
        )
        XCTAssertTrue(
            card.recommendedActions.contains(
                .reviewMedicineSources
            )
        )
    }

    func testMissingSourcesNeverExposeUnverifiedDosageText() {
        let unverifiedDosageText =
            "UNVERIFIED PLACEHOLDER: take an arbitrary amount"
        let medicine = Medicine(
            id: "test-unverified-medicine",
            canonicalName: "Unverified Medicine",
            aliases: [],
            activeIngredientIDs: ["unverified-ingredient"],
            medicineCategory: .other,
            sourceReferences: [],
            dosageTextFromSource: unverifiedDosageText,
            contraindicationTags: [],
            warnings: [],
            dataVersion: "test-v1"
        )
        let card = ActionCardFactory().makeCard(
            resolution: makeResolvedResolution(
                medicine: medicine
            ),
            assessment: makeAssessment(
                level: .green,
                actions: [.followVerifiedSourceInformation],
                completeness: .insufficient
            ),
            generatedAt: pipelineTestDate
        )

        XCTAssertTrue(card.riskLevel >= .yellow)
        XCTAssertTrue(card.sourceReferences.isEmpty)
        XCTAssertFalse(
            card.recommendedActions.contains(
                .followVerifiedSourceInformation
            )
        )
        XCTAssertFalse(
            card.primaryInstruction.contains(unverifiedDosageText)
        )
        XCTAssertFalse(
            card.warnings.contains {
                $0.contains(unverifiedDosageText)
            }
        )
    }

    func testResolvedCardPreservesWarningsAndSources() throws {
        let medicine = try XCTUnwrap(
            loadDemoCatalog().medicines.first
        )
        let card = ActionCardFactory().makeCard(
            resolution: makeResolvedResolution(
                medicine: medicine
            ),
            assessment: makeAssessment(
                level: .green,
                actions: [.followVerifiedSourceInformation]
            ),
            generatedAt: pipelineTestDate
        )

        XCTAssertEqual(card.title, medicine.canonicalName)
        XCTAssertEqual(
            card.sourceReferences,
            medicine.sourceReferences
        )
        XCTAssertTrue(
            card.warnings.contains(
                DemoMedicineCatalogPolicy.requiredDisclaimer
            )
        )
        XCTAssertFalse(card.mustConfirmMedicine)
    }
}
