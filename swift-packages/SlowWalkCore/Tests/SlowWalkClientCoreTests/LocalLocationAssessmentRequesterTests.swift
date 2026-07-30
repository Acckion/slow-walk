import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkLocationRisk
import XCTest

final class LocalLocationAssessmentRequesterTests: XCTestCase {
    func testAssessmentRunsLocationEngineLocally() async throws {
        let request = makeRequest()
        let requester = LocalLocationAssessmentRequester(
            assessor: LocationRiskEngine(
                clock: FixedClientClock(date: clientTestDate)
            )
        )

        let response = try await requester.assess(request: request)

        XCTAssertEqual(response.requestID, request.requestID)
        XCTAssertEqual(response.apiVersion, request.apiVersion)
        XCTAssertEqual(response.assessment.level, response.actionCard.riskLevel)
        XCTAssertEqual(response.generatedAt, response.assessment.assessedAt)
        XCTAssertEqual(response.warnings, response.actionCard.warnings)
        XCTAssertNoThrow(
            try LocationAssessmentResponseValidator().validate(
                response,
                for: request
            )
        )
    }

    func testUnsupportedVersionIsRejectedBeforeAssessment() async {
        let requester = LocalLocationAssessmentRequester(
            assessor: LocationRiskEngine(
                clock: FixedClientClock(date: clientTestDate)
            )
        )

        do {
            _ = try await requester.assess(
                request: makeRequest(apiVersion: "v999")
            )
            XCTFail("Expected an unsupported version error.")
        } catch let error as ClientAPIError {
            XCTAssertEqual(error.error.code, .unsupportedAPIVersion)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidatorRejectsMismatchedRequestID() {
        let request = makeRequest()
        let response = makeLocationResponse(
            requestID: clientTestUUID(72)
        )

        XCTAssertThrowsError(
            try LocationAssessmentResponseValidator().validate(
                response,
                for: request
            )
        ) { error in
            XCTAssertEqual(
                error as? LocationAssessmentResponseValidationError,
                .requestIDMismatch
            )
        }
    }

    private func makeRequest(
        apiVersion: String = SlowWalkAPI.version
    ) -> LocationAssessmentRequestDTO {
        LocationAssessmentRequestDTO(
            destination: makeDestination(),
            recentSamples: [
                makeLocationSample(offset: -20, latitudeDelta: 0.001),
                makeLocationSample(offset: -10, latitudeDelta: 0.0005),
                makeLocationSample(offset: 0),
            ],
            requestID: clientTestUUID(71),
            apiVersion: apiVersion
        )
    }
}
