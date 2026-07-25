import Foundation
import SlowWalkAPIContracts
import SlowWalkMedicineKnowledge
import XCTest

final class MedicineKnowledgeDTOTests: XCTestCase {
    func testSearchDTOsRoundTripWithStructuredEvidence()
        throws
    {
        let requestID = UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 51
            )
        )
        let request = MedicineKnowledgeSearchRequestDTO(
            normalizedQuery: "acetaminophen",
            requestID: requestID,
            apiVersion: SlowWalkAPI.version
        )
        let result = MedicineKnowledgeSearchResult(
            normalizedQuery: request.normalizedQuery,
            candidates: [],
            sourceStatus: .partial,
            cacheStatus: .staleOffline,
            completeness: 0.5,
            sourceReferences: [],
            warnings: [
                MedicineKnowledgeWarning(
                    code: .offlineCacheUsed,
                    message:
                        "Stale demo cache is in offline use."
                ),
            ],
            sourceVersions: [
                "demo-source": "demo-v1",
            ],
            generatedAt: dtoTestDate,
            isOffline: true
        )
        let response = MedicineKnowledgeSearchResponseDTO(
            requestID: requestID,
            result: result,
            apiVersion: SlowWalkAPI.version
        )
        let envelope = MedicineKnowledgeEnvelope(
            request: request,
            response: response
        )

        let data = try SlowWalkJSONCoding.makeEncoder()
            .encode(envelope)
        let decoded = try SlowWalkJSONCoding.makeDecoder()
            .decode(
                MedicineKnowledgeEnvelope.self,
                from: data
            )

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(
            decoded.response.knowledgeCacheStatus,
            .staleOffline
        )
        XCTAssertEqual(
            decoded.response.warnings.first?.code,
            .offlineCacheUsed
        )
        XCTAssertTrue(
            decoded.response.governanceVerdict
                .requiresConservativeAction
        )
        XCTAssertFalse(
            decoded.response.governanceVerdict
                .allowsDosageDisplay
        )
    }
}

private struct MedicineKnowledgeEnvelope:
    Codable,
    Equatable
{
    let request: MedicineKnowledgeSearchRequestDTO
    let response: MedicineKnowledgeSearchResponseDTO
}

private let dtoTestDate = Date(
    timeIntervalSince1970: 1_753_315_200
)
