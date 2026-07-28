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
        let decoder = SlowWalkJSONCoding.makeDecoder()

        for filename in fixtureFiles {
            let data = try Data(
                contentsOf: fixtureDirectory
                    .appendingPathComponent(filename)
            )
            let fixture = try decoder.decode(
                MedicineDemoFixture.self,
                from: data
            )

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
        let decoder = SlowWalkJSONCoding.makeDecoder()
        var actual: [String: String] = [:]

        for filename in fixtureFiles {
            let data = try Data(
                contentsOf: fixtureDirectory
                    .appendingPathComponent(filename)
            )
            let fixture = try decoder.decode(
                MedicineDemoFixture.self,
                from: data
            )
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
                "knowledgeWarning": "result",
                "redRisk": "result",
            ]
        )
    }

    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("demo-fixtures")
    }
}

private struct MedicineDemoFixture: Decodable {
    let fixtureID: String
    let disclaimer: String
    let request: MedicineAssessmentRequestDTO
    let response: MedicineAssessmentResponseDTO
    let expectation: MedicineDemoExpectation
}

private struct MedicineDemoExpectation: Decodable {
    let allowsOrdinaryExplanation: Bool
    let expectedActionCardPrimaryInstruction: String
    let expectedActionCardTitle: String
    let expectedPresentationVariant: String
    let expectedRiskLevel: String
    let expectedViewState: String
    let recommendContactFamily: Bool
    let recommendContactHealthcareProfessional: Bool
}
