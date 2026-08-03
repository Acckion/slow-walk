import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkLocationRisk
import XCTest

final class LocalLocationAssessmentRequesterTests: XCTestCase {
    func testAssessmentMatchesDirectLocationEngineOutput() async throws {
        let request = makeRequest()
        let engine = LocationRiskEngine(
            clock: FixedClientClock(date: clientTestDate)
        )
        let cardFactory = LocationActionCardFactory()
        let requester = LocalLocationAssessmentRequester(
            assessor: engine,
            clock: FixedClientClock(date: clientTestDate),
            actionCardFactory: cardFactory
        )

        let response = try await requester.assess(request: request)
        let expectedAssessment = try engine.assess(
            destination: request.destination,
            recentSamples: request.recentSamples
        )
        let expectedCard = cardFactory.makeCard(from: expectedAssessment)

        XCTAssertEqual(response.requestID, request.requestID)
        XCTAssertEqual(response.apiVersion, request.apiVersion)
        XCTAssertEqual(response.assessment, expectedAssessment)
        XCTAssertEqual(response.actionCard, expectedCard)
        XCTAssertEqual(response.generatedAt, expectedAssessment.assessedAt)
        XCTAssertEqual(response.warnings, expectedCard.warnings)
        XCTAssertNoThrow(
            try LocationAssessmentResponseValidator().validate(
                response,
                for: request
            )
        )
    }

    func testUnsupportedVersionIsRejectedBeforeAssessment() async {
        let requester = makeRequester()

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

    func testInvalidDestinationUsesCanonicalValidationError() async {
        let destination = Destination(
            id: " ",
            name: "",
            point: GeoPoint(latitude: 31.2304, longitude: 121.4737),
            geofenceRadiusMeters: 50
        )

        do {
            _ = try await makeRequester().assess(
                request: makeRequest(destination: destination)
            )
            XCTFail("Expected destination validation error.")
        } catch let error as ClientAPIError {
            XCTAssertEqual(error.error.code, .validationError)
            XCTAssertEqual(error.error.details?.count, 2)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAllInaccurateSamplesUseCanonicalAccuracyError() async {
        let samples = [
            makeLocationSample(offset: -20, accuracy: 500),
            makeLocationSample(offset: -10, accuracy: 500),
            makeLocationSample(offset: 0, accuracy: 500),
        ]

        await assertAPIError(
            .locationAccuracyInsufficient,
            for: makeRequest(samples: samples)
        )
    }

    func testStaleSamplesUseCanonicalStaleError() async {
        let samples = [
            makeLocationSample(offset: -2_000),
            makeLocationSample(offset: -1_900),
        ]

        await assertAPIError(
            .locationDataStale,
            for: makeRequest(samples: samples)
        )
    }

    func testInsufficientHistoryUsesCanonicalError() async {
        await assertAPIError(
            .insufficientLocationHistory,
            for: makeRequest(
                samples: [makeLocationSample(offset: 0)]
            )
        )
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

    private func assertAPIError(
        _ expectedCode: APIErrorCode,
        for request: LocationAssessmentRequestDTO,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await makeRequester().assess(request: request)
            XCTFail("Expected \(expectedCode).", file: file, line: line)
        } catch let error as ClientAPIError {
            XCTAssertEqual(
                error.error.code,
                expectedCode,
                file: file,
                line: line
            )
            XCTAssertEqual(
                error.error.requestID,
                request.requestID,
                file: file,
                line: line
            )
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private func makeRequest(
        apiVersion: String = SlowWalkAPI.version,
        destination: Destination = makeDestination(),
        samples: [LocationSample]? = nil
    ) -> LocationAssessmentRequestDTO {
        LocationAssessmentRequestDTO(
            destination: destination,
            recentSamples: samples ?? [
                makeLocationSample(offset: -20, latitudeDelta: 0.001),
                makeLocationSample(offset: -10, latitudeDelta: 0.0005),
                makeLocationSample(offset: 0),
            ],
            requestID: clientTestUUID(71),
            apiVersion: apiVersion
        )
    }

    private func makeRequester() -> LocalLocationAssessmentRequester {
        LocalLocationAssessmentRequester(
            assessor: LocationRiskEngine(
                clock: FixedClientClock(date: clientTestDate)
            ),
            clock: FixedClientClock(date: clientTestDate)
        )
    }
}
