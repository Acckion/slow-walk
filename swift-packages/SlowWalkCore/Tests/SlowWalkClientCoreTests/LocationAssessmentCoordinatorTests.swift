import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain
import SlowWalkLocationRisk
import XCTest

final class LocationAssessmentCoordinatorTests:
    XCTestCase
{
    func testInsufficientSamplesDoesNotCallNetwork()
        async throws
    {
        let provider = try makeProvider()
        await provider.append(
            makeLocationSample(offset: 0),
            asOf: clientTestDate
        )
        let coordinator = try makeCoordinator(
            provider: provider,
            requester: CancellableLocationRequester()
        )

        let state = await coordinator.assess(
            destination: makeDestination(),
            requestID: clientTestUUID(50)
        )

        guard
            case
                .insufficientSamples(let details) = state
        else {
            return XCTFail(
                "Expected insufficient samples."
            )
        }
        XCTAssertEqual(details.availableSampleCount, 1)
        XCTAssertEqual(details.requiredSampleCount, 2)
    }

    func testNormalAssessmentSendsBoundedRequest()
        async throws
    {
        let provider = try makeProvider()
        await provider.append(
            contentsOf: [
                makeLocationSample(offset: -20),
                makeLocationSample(offset: -10),
                makeLocationSample(offset: 0),
            ],
            asOf: clientTestDate
        )
        let response = makeLocationResponse()
        let requester = CapturingLocationRequester(
            response: response
        )
        let coordinator = try makeCoordinator(
            provider: provider,
            requester: requester
        )

        let state = await coordinator.assess(
            destination: makeDestination(),
            requestID: response.requestID
        )

        guard case .result(let presentation) = state
        else {
            return XCTFail("Expected location result.")
        }
        XCTAssertEqual(presentation.response, response)
        let captured = await requester.request
        let request = try XCTUnwrap(captured)
        XCTAssertEqual(
            request.destination,
            makeDestination()
        )
        XCTAssertEqual(request.recentSamples.count, 3)
        XCTAssertEqual(
            request.apiVersion,
            SlowWalkAPI.version
        )
    }

    func testLowAccuracyResponseRemainsExplicit()
        async throws
    {
        let response = makeLocationResponse(
            requestID: clientTestUUID(50),
            level: .yellow,
            reasonCode:
                .locationAccuracyInsufficient,
            accuracy: .insufficient,
            qualityStatus: .insufficient
        )
        let state = try await runWithSamples(
            requester:
                MockLocationAssessmentRequester(
                    behavior: .response(response)
                )
        )

        guard case .result(let presentation) = state
        else {
            return XCTFail("Expected location result.")
        }
        XCTAssertEqual(
            presentation.response.assessment
                .dataQuality.accuracy,
            .insufficient
        )
        XCTAssertEqual(
            presentation.risk.attention,
            .reviewRequired
        )
    }

    func testArrivedResponseKeepsRoutineSemantics()
        async throws
    {
        let response = makeLocationResponse(
            requestID: clientTestUUID(50),
            level: .green,
            reasonCode: .arrivedAtDestination
        )
        let state = try await runWithSamples(
            requester:
                MockLocationAssessmentRequester(
                    behavior: .response(response)
                )
        )

        guard case .result(let presentation) = state
        else {
            return XCTFail("Expected location result.")
        }
        XCTAssertEqual(
            presentation.risk.attention,
            .routine
        )
        XCTAssertEqual(
            presentation.response.assessment
                .reasons.first?.code,
            .arrivedAtDestination
        )
    }

    func testRedLocationResultRequiresImmediateAttention()
        async throws
    {
        let response = makeLocationResponse(
            requestID: clientTestUUID(50),
            level: .red,
            reasonCode: .multipleHighRiskSignals
        )
        let state = try await runWithSamples(
            requester:
                MockLocationAssessmentRequester(
                    behavior: .response(response)
                )
        )

        guard case .result(let presentation) = state
        else {
            return XCTFail("Expected location result.")
        }
        XCTAssertEqual(presentation.risk.level, .red)
        XCTAssertTrue(
            presentation.risk
                .requiresImmediateAttention
        )
    }

    func testRequesterCancellationIsDistinctState()
        async throws
    {
        let state = try await runWithSamples(
            requester:
                MockLocationAssessmentRequester(
                    behavior: .cancellation
                )
        )

        XCTAssertEqual(state, .cancelled)
    }

    func testExplicitCancellationStopsSampling()
        async throws
    {
        let provider = try makeProvider()
        await provider.append(
            contentsOf: [
                makeLocationSample(offset: -10),
                makeLocationSample(offset: 0),
            ],
            asOf: clientTestDate
        )
        let coordinator = try makeCoordinator(
            provider: provider,
            requester: CancellableLocationRequester()
        )
        let task = Task {
            await coordinator.assess(
                destination: makeDestination(),
                requestID: clientTestUUID(51)
            )
        }

        var reachedAssessing = false
        for _ in 0..<1_000 {
            if case .assessing =
                await coordinator.state
            {
                reachedAssessing = true
                break
            }
            await Task.yield()
        }
        XCTAssertTrue(reachedAssessing)

        await coordinator.cancelCurrentAssessment()
        let result = await task.value
        let sampling = await provider.isSampling()

        XCTAssertEqual(result, .cancelled)
        XCTAssertFalse(sampling)
    }

    func testLocationAPIErrorUsesCanonicalCode()
        async throws
    {
        let requestID = clientTestUUID(52)
        let error = APIErrorDTO(
            code: .locationDataStale,
            message: "Location data is stale.",
            requestID: requestID,
            details: nil
        )
        let state = try await runWithSamples(
            requester:
                MockLocationAssessmentRequester(
                    behavior: .apiError(error)
                )
        )

        guard case .failed(let failure) = state else {
            return XCTFail("Expected API failure.")
        }
        XCTAssertEqual(
            failure.apiErrorCode,
            .locationDataStale
        )
        XCTAssertEqual(failure.requestID, requestID)
    }

    func testProviderExposesPlatformNeutralStatus()
        async throws
    {
        let provider = try makeProvider(
            status: LocationSamplingStatus(
                authorization: .denied,
                availability: .available,
                preciseLocationAvailable: nil
            )
        )

        let status = await provider.currentStatus()
        XCTAssertEqual(status.authorization, .denied)
        do {
            try await provider.startSampling()
            XCTFail("Expected unavailable failure.")
        } catch {
            XCTAssertEqual(
                error as? ClientTransportError,
                .unavailable
            )
        }
    }

    func testCoordinatorPrivacyClearRemovesHistory()
        async throws
    {
        let provider = try makeProvider()
        await provider.append(
            makeLocationSample(offset: 0),
            asOf: clientTestDate
        )
        let coordinator = try makeCoordinator(
            provider: provider,
            requester: CancellableLocationRequester()
        )

        await coordinator.clearLocationHistory()

        let samples = await provider.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertTrue(samples.isEmpty)
    }

    private func makeProvider(
        status: LocationSamplingStatus =
            LocationSamplingStatus(
                authorization: .authorized,
                availability: .available,
                preciseLocationAvailable: true
            )
    ) throws -> MockLocationSampleProvider {
        MockLocationSampleProvider(
            configuration:
                try LocationHistoryConfiguration(
                    maximumSampleCount: 10,
                    maximumSampleAge: 300
                ),
            status: status
        )
    }

    private func makeCoordinator(
        provider: any LocationSampleProviding,
        requester:
            any LocationAssessmentRequesting
    ) throws -> LocationAssessmentCoordinator {
        try LocationAssessmentCoordinator(
            sampleProvider: provider,
            requestBuilder:
                LocationAssessmentRequestBuilder(
                    historyConfiguration:
                        try LocationHistoryConfiguration(
                            maximumSampleCount: 10,
                            maximumSampleAge: 300
                        )
                ),
            requester: requester,
            clock: FixedClientClock(
                date: clientTestDate
            ),
            apiVersion: SlowWalkAPI.version,
            minimumSampleCount: 2
        )
    }

    private func runWithSamples(
        requester:
            any LocationAssessmentRequesting
    ) async throws -> LocationAssessmentViewState {
        let provider = try makeProvider()
        await provider.append(
            contentsOf: [
                makeLocationSample(offset: -10),
                makeLocationSample(offset: 0),
            ],
            asOf: clientTestDate
        )
        let coordinator = try makeCoordinator(
            provider: provider,
            requester: requester
        )
        return await coordinator.assess(
            destination: makeDestination(),
            requestID: clientTestUUID(50)
        )
    }
}
