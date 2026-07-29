import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
import XCTest

final class DemoFixtureContractTests: XCTestCase {
    private let fixtureFiles = [
        "medicine-normal.json",
        "medicine-ambiguous.json",
        "medicine-health-warning.json",
        "medicine-source-warning.json",
        "medicine-red-risk.json",
    ]

    func testMedicineAssessContractRemainsCanonical() {
        XCTAssertEqual(
            SlowWalkAPI.Endpoint.medicineAssess.path,
            "/api/v1/medicine/assess"
        )
        XCTAssertEqual(SlowWalkAPI.version, "v1")
        XCTAssertTrue(
            SlowWalkAPI.supports(
                bodyVersion: "v1",
                for: .medicineAssess
            )
        )
    }

    func testStableRiskLevelsAndCanonicalErrorCodes() {
        XCTAssertEqual(
            RiskLevel.allCases.map(\.rawValue),
            ["green", "yellow", "orange", "red"]
        )

        for code in APIErrorCode.allCases {
            XCTAssertEqual(
                code.rawValue,
                code.rawValue.uppercased(),
                "\(code) must encode as canonical UPPER_SNAKE_CASE"
            )
        }
    }

    func testDemoFixturesDecodeAsCanonicalDTOs() throws {
        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)

            XCTAssertEqual(
                fixture.disclaimer,
                "DEMO DATA — NOT FOR CLINICAL USE",
                filename
            )
            XCTAssertEqual(
                fixture.request.apiVersion,
                SlowWalkAPI.version,
                filename
            )
            XCTAssertEqual(
                fixture.response.apiVersion,
                SlowWalkAPI.version,
                filename
            )
            XCTAssertEqual(
                fixture.request.requestID,
                fixture.response.requestID,
                filename
            )
            XCTAssertEqual(
                fixture.response.actionCard.riskLevel.rawValue,
                fixture.expectation.expectedRiskLevel,
                filename
            )
            XCTAssertEqual(
                fixture.response.actionCard.title,
                fixture.expectation.expectedActionCardTitle,
                filename
            )
            XCTAssertEqual(
                fixture.response.actionCard.primaryInstruction,
                fixture.expectation
                    .expectedActionCardPrimaryInstruction,
                filename
            )
            XCTAssertEqual(
                fixture.response.actionCard.recommendedActions
                    .contains(.notifyFamilyMember),
                fixture.expectation.recommendContactFamily,
                filename
            )
            XCTAssertEqual(
                fixture.response.actionCard.recommendedActions
                    .contains(.consultHealthcareProfessional),
                fixture.expectation
                    .recommendContactHealthcareProfessional,
                filename
            )
        }
    }

    func testFixtureIDsAndViewStateExpectationsAreFrozen() throws {
        var actual: [String: String] = [:]

        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)
            actual[fixture.fixtureID] =
                fixture.expectation.expectedViewState

            if fixture.fixtureID == "ambiguous" {
                XCTAssertEqual(
                    fixture.response.resolution.status,
                    .ambiguous
                )
                XCTAssertTrue(
                    fixture.response.actionCard
                        .mustConfirmMedicine
                )
                XCTAssertNil(fixture.response.assessment)
            } else {
                XCTAssertEqual(
                    fixture.response.resolution.status,
                    .resolved,
                    filename
                )
                XCTAssertNotNil(
                    fixture.response.resolution
                        .selectedMedicine,
                    filename
                )
                XCTAssertNotNil(
                    fixture.response.assessment,
                    filename
                )
            }
        }

        XCTAssertEqual(
            actual,
            [
                "normal": "result",
                "ambiguous":
                    "requiresMedicineConfirmation",
                "healthWarning": "result",
                "knowledgeWarning":
                    "requiresMedicineConfirmation",
                "redRisk": "result",
            ]
        )
    }

    /// The coordinator maps a resolved response that still requires user
    /// confirmation to `requiresMedicineConfirmation`, never to `result`.
    func testPresentationExpectationsMatchCoordinatorSemantics() throws {
        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)
            let resolution = fixture.response.resolution
            let showsResult = resolution.status == .resolved
                && !resolution.requiresUserConfirmation
            let expectedState = fixture.expectation
                .expectedViewState

            XCTAssertEqual(
                expectedState,
                showsResult
                    ? "result"
                    : "requiresMedicineConfirmation",
                filename
            )
            XCTAssertEqual(
                fixture.expectation.expectedPresentationVariant,
                fixture.fixtureID,
                "presentation variant must stay attached to its fixture"
            )

            if fixture.expectation.allowsOrdinaryExplanation {
                XCTAssertEqual(
                    expectedState,
                    "result",
                    "\(filename): ordinary explanation requires " +
                        "a settled result"
                )
                XCTAssertFalse(
                    fixture.response.actionCard.mustConfirmMedicine,
                    filename
                )
                XCTAssertNotEqual(
                    fixture.response.actionCard.riskLevel,
                    .red,
                    "\(filename): a red card never reads as an " +
                        "ordinary explanation"
                )
            }
        }
    }

    /// Frozen action lists. The golden tests own full-DTO equality; these
    /// freeze the safety-critical action content and order explicitly so a
    /// hand edit cannot silently drop a do-not-take or confirmation action.
    func testRecommendedActionsAreFrozenInContentAndOrder() throws {
        let expectedAssessmentActions: [String: [RecommendedAction]] = [
            "normal": [.followVerifiedSourceInformation],
            "healthWarning": [
                .consultHealthcareProfessional,
                .remeasureBodyMetrics,
            ],
            "knowledgeWarning": [
                .consultHealthcareProfessional,
                .reviewMedicineSources,
            ],
            "redRisk": [
                .consultHealthcareProfessional,
                .doNotTakeUntilMedicineConfirmed,
                .notifyFamilyMember,
            ],
        ]
        let expectedCardActions: [String: [RecommendedAction]] = [
            "normal": [.followVerifiedSourceInformation],
            "ambiguous": [
                .doNotTakeUntilMedicineConfirmed,
                .retakeMedicinePhoto,
                .consultHealthcareProfessional,
            ],
            "healthWarning": [
                .consultHealthcareProfessional,
                .reviewMedicineSources,
                .remeasureBodyMetrics,
            ],
            "knowledgeWarning": [
                .doNotTakeUntilMedicineConfirmed,
                .consultHealthcareProfessional,
                .reviewMedicineSources,
            ],
            "redRisk": [
                .doNotTakeUntilMedicineConfirmed,
                .consultHealthcareProfessional,
                .notifyFamilyMember,
            ],
        ]

        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)
            let id = fixture.fixtureID

            XCTAssertEqual(
                fixture.response.assessment?.recommendedActions,
                expectedAssessmentActions[id],
                "\(filename): assessment action content/order"
            )
            XCTAssertEqual(
                fixture.response.actionCard.recommendedActions,
                expectedCardActions[id],
                "\(filename): action card action content/order"
            )

            if let assessment = fixture.response.assessment {
                XCTAssertTrue(
                    Set(
                        fixture.response.actionCard
                            .recommendedActions
                    ).isSuperset(
                        of: Set(assessment.recommendedActions)
                    ),
                    "\(filename): the card must keep every assessed action"
                )
                if assessment.level == .red {
                    XCTAssertTrue(
                        fixture.response.actionCard
                            .recommendedActions
                            .contains(
                                .doNotTakeUntilMedicineConfirmed
                            ),
                        "\(filename): red cards must block taking"
                    )
                    XCTAssertFalse(
                        fixture.response.actionCard
                            .recommendedActions
                            .contains(
                                .followVerifiedSourceInformation
                            ),
                        "\(filename): red cards must not read as routine"
                    )
                }
            }
        }
    }

    func testCanonicalVersionAndConfigurationStrings() throws {
        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)

            XCTAssertEqual(
                fixture.response.resolution.evidence.matcherVersion,
                "slowwalk-resolver-v1",
                filename
            )
            XCTAssertEqual(
                fixture.response.healthContextValidation?
                    .configurationNotices,
                [
                    "DEMO DATA QUALITY CONFIGURATION — NOT A CLINICAL DIAGNOSTIC STANDARD",
                    "NOT FOR CLINICAL USE",
                ],
                filename
            )
            XCTAssertEqual(
                fixture.response.sourceDataVersion,
                "mock-authoritative-medicine-source=demo-authoritative-v1;" +
                    "mock-secondary-medicine-source=demo-secondary-v1",
                filename
            )
        }
    }

    func testResolutionCandidatesAreConsistentWithStatus() throws {
        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)
            let resolution = fixture.response.resolution

            switch resolution.status {
            case .resolved:
                XCTAssertFalse(
                    resolution.candidates.isEmpty,
                    "\(filename): a resolved response keeps its candidates"
                )
                XCTAssertEqual(
                    resolution.selectedMedicine?.id,
                    resolution.candidates.first?.medicine.id,
                    filename
                )
            case .ambiguous:
                XCTAssertGreaterThanOrEqual(
                    resolution.candidates.count,
                    2,
                    "\(filename): ambiguity requires real candidates"
                )
                XCTAssertNil(resolution.selectedMedicine, filename)
                XCTAssertTrue(
                    resolution.requiresUserConfirmation,
                    filename
                )
            case .insufficientEvidence, .notFound, .recognitionFailed:
                XCTAssertNil(resolution.selectedMedicine, filename)
                XCTAssertTrue(
                    resolution.requiresUserConfirmation,
                    filename
                )
            }

            for candidate in resolution.candidates {
                XCTAssertTrue(
                    (0 ... 1).contains(candidate.matchScore),
                    filename
                )
                XCTAssertFalse(
                    candidate.matchReasons.isEmpty,
                    filename
                )
            }
        }
    }

    func testEvidenceCompletenessIsConsistentWithWarnings() throws {
        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)
            guard let assessment = fixture.response.assessment,
                  let validation = fixture.response
                  .healthContextValidation
            else {
                continue
            }

            XCTAssertEqual(
                assessment.evidenceCompleteness == .complete,
                validation.warnings.isEmpty,
                "\(filename): stale or missing evidence must not " +
                    "read as complete"
            )
            if assessment.evidenceCompleteness != .complete {
                XCTAssertTrue(
                    assessment.requiresProfessionalAdvice,
                    filename
                )
            }
        }
    }

    func testKnowledgeAndCacheStatesAreJointlyConsistent() throws {
        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)
            let response = fixture.response

            XCTAssertEqual(
                response.cacheHit,
                response.knowledgeCacheStatus == .hit,
                filename
            )
            XCTAssertEqual(
                response.medicineKnowledge == nil,
                response.knowledgeCacheStatus == nil,
                "\(filename): the knowledge object and its cache " +
                    "status must arrive together"
            )
            XCTAssertEqual(
                response.medicineKnowledge?.cacheStatus,
                response.knowledgeCacheStatus,
                filename
            )

            if response.knowledgeCacheStatus == .staleOffline {
                XCTAssertEqual(
                    response.resolutionCacheStatus,
                    .expired,
                    filename
                )
                XCTAssertFalse(response.cacheHit, filename)
                XCTAssertEqual(
                    response.medicineKnowledge?.isOffline,
                    true,
                    filename
                )
                XCTAssertTrue(
                    response.actionCard.mustConfirmMedicine,
                    "\(filename): stale offline knowledge must " +
                        "require confirmation"
                )
            }
        }
    }

    /// The fixture carries the DEMO DATA label inside the payload; the app
    /// shell must still render it on screen. No fixture may carry dosage
    /// text, so the demo cannot display dosing instructions.
    func testDisclaimerAndSafetyBoundaries() throws {
        for filename in fixtureFiles {
            let fixture = try DemoFixtureSupport.load(filename)

            XCTAssertEqual(
                fixture.disclaimer,
                "DEMO DATA — NOT FOR CLINICAL USE",
                filename
            )

            let medicines = fixture.response.resolution.candidates
                .map(\.medicine)
                + [fixture.response.resolution.selectedMedicine]
                .compactMap { $0 }
            for medicine in medicines {
                XCTAssertTrue(
                    medicine.warnings.contains(
                        "DEMO DATA — NOT FOR CLINICAL USE"
                    ),
                    "\(filename): \(medicine.id) lost its demo label"
                )
                XCTAssertNil(
                    medicine.dosageTextFromSource,
                    "\(filename): fixtures must not carry dosage text"
                )
            }

            if fixture.response.resolution.status == .resolved {
                XCTAssertTrue(
                    fixture.response.actionCard.warnings.contains(
                        "DEMO DATA — NOT FOR CLINICAL USE"
                    ),
                    filename
                )
            }
            XCTAssertTrue(
                fixture.response.healthContextValidation?
                    .configurationNotices
                    .contains("NOT FOR CLINICAL USE") == true,
                filename
            )
        }
    }
}
