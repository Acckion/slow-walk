import Foundation
import SlowWalkMedicineKnowledge
import XCTest

final class MedicineKnowledgeFixtureTests:
    XCTestCase
{
    func testEveryMedicineKnowledgeFixtureDecodes()
        throws
    {
        let expectedNames = [
            "consistent-sources",
            "source-conflict",
            "primary-timeout",
            "secondary-available",
            "not-modified",
            "expired-cache",
            "source-version-change",
            "missing-dosage",
            "invalid-response",
            "medicine-not-found",
        ]
        let decoder = JSONDecoder()

        for name in expectedNames {
            let url = try XCTUnwrap(
                Bundle.module.url(
                    forResource: name,
                    withExtension: "json"
                ),
                "Missing fixture: \(name).json"
            )
            let fixture = try decoder.decode(
                MedicineKnowledgeScenarioFixture.self,
                from: Data(contentsOf: url)
            )
            XCTAssertEqual(
                fixture.disclaimer,
                MedicineKnowledgeSafety.demoDisclaimer
            )
            XCTAssertFalse(fixture.scenario.isEmpty)
            XCTAssertFalse(
                fixture.sourceDataVersion.isEmpty
            )
            XCTAssertTrue(
                fixture.expectedSourceStatus != nil
                    || fixture.expectedErrorCode != nil
            )
        }
    }
}

private struct MedicineKnowledgeScenarioFixture:
    Decodable
{
    let scenario: String
    let disclaimer: String
    let httpStatus: Int?
    let expectedSourceStatus: String?
    let expectedCacheStatus: String?
    let expectedErrorCode: String?
    let sourceDataVersion: String
}
