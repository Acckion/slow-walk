import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkLocationRisk
import XCTest

final class LocationHistoryBufferTests: XCTestCase {
    func testAppendSingleSample() async throws {
        let buffer = try makeBuffer()
        let sample = makeLocationSample(offset: 0)

        await buffer.append(
            sample,
            asOf: clientTestDate
        )

        let samples = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertEqual(samples, [sample])
    }

    func testSamplesAreSortedByRecordedAt()
        async throws
    {
        let buffer = try makeBuffer()
        let samples = [
            makeLocationSample(offset: -10),
            makeLocationSample(offset: -30),
            makeLocationSample(offset: -20),
        ]

        await buffer.append(
            contentsOf: samples,
            asOf: clientTestDate
        )

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertEqual(
            result.map(\.recordedAt),
            samples.map(\.recordedAt).sorted()
        )
    }

    func testOutOfOrderCallbackRetainsValidSample()
        async throws
    {
        let buffer = try makeBuffer()
        let newest = makeLocationSample(offset: 0)
        let earlier = makeLocationSample(offset: -20)

        await buffer.append(
            newest,
            asOf: clientTestDate
        )
        await buffer.append(
            earlier,
            asOf: clientTestDate
        )

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertEqual(result, [earlier, newest])
    }

    func testExactDuplicateIsRemoved() async throws {
        let buffer = try makeBuffer()
        let sample = makeLocationSample(offset: 0)

        await buffer.append(
            contentsOf: [sample, sample],
            asOf: clientTestDate
        )

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertEqual(result, [sample])
    }

    func testMaximumCapacityKeepsNewestSamples()
        async throws
    {
        let configuration =
            try LocationHistoryConfiguration(
                maximumSampleCount: 2,
                maximumSampleAge: 300
            )
        let buffer = LocationHistoryBuffer(
            configuration: configuration
        )

        await buffer.append(
            contentsOf: [
                makeLocationSample(offset: -30),
                makeLocationSample(offset: -20),
                makeLocationSample(offset: -10),
            ],
            asOf: clientTestDate
        )

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertEqual(
            result.map(\.recordedAt),
            [
                clientTestDate.addingTimeInterval(-20),
                clientTestDate.addingTimeInterval(-10),
            ]
        )
    }

    func testTimeWindowCleanupRetainsBoundary()
        async throws
    {
        let buffer = try makeBuffer(maximumAge: 60)
        let boundary = makeLocationSample(offset: -60)
        let expired = makeLocationSample(offset: -61)

        await buffer.append(
            contentsOf: [expired, boundary],
            asOf: clientTestDate
        )

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertEqual(result, [boundary])
    }

    func testClearRemovesPrivacyHistory()
        async throws
    {
        let buffer = try makeBuffer()
        await buffer.append(
            makeLocationSample(offset: 0),
            asOf: clientTestDate
        )

        await buffer.clear()

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testConcurrentAppendIsDeterministic()
        async throws
    {
        let buffer = try makeBuffer()
        let samples = (0 ..< 20).map {
            makeLocationSample(
                offset: -TimeInterval($0),
                latitudeDelta:
                    Double($0) / 100_000
            )
        }

        await withTaskGroup(of: Void.self) { group in
            for sample in samples {
                group.addTask {
                    await buffer.append(
                        sample,
                        asOf: clientTestDate
                    )
                }
            }
        }

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )
        XCTAssertEqual(result.count, 20)
        XCTAssertEqual(
            result.map(\.recordedAt),
            result.map(\.recordedAt).sorted()
        )
    }

    func testExpiredTrajectoryIsNeverRetained()
        async throws
    {
        let buffer = try makeBuffer(maximumAge: 30)
        await buffer.append(
            makeLocationSample(offset: -31),
            asOf: clientTestDate
        )

        let result = await buffer.recentSamples(
            asOf: clientTestDate
        )

        XCTAssertTrue(result.isEmpty)
    }

    func testRequestBuilderDropsExpiredAndBoundsCount()
        throws
    {
        let configuration =
            try LocationHistoryConfiguration(
                maximumSampleCount: 2,
                maximumSampleAge: 30
            )
        let builder = LocationAssessmentRequestBuilder(
            historyConfiguration: configuration
        )

        let request = builder.makeRequest(
            destination: makeDestination(),
            samples: [
                makeLocationSample(offset: -100),
                makeLocationSample(offset: -20),
                makeLocationSample(offset: -10),
                makeLocationSample(offset: 0),
            ],
            requestID: clientTestUUID(30),
            apiVersion: SlowWalkAPI.version,
            referenceDate: clientTestDate
        )

        XCTAssertEqual(request.recentSamples.count, 2)
        XCTAssertEqual(
            request.recentSamples.map(\.recordedAt),
            [
                clientTestDate.addingTimeInterval(-10),
                clientTestDate,
            ]
        )
    }

    func testInvalidHistoryConfigurationIsRejected() {
        XCTAssertThrowsError(
            try LocationHistoryConfiguration(
                maximumSampleCount: 0,
                maximumSampleAge: 60
            )
        )
        XCTAssertThrowsError(
            try LocationHistoryConfiguration(
                maximumSampleCount: 10,
                maximumSampleAge: 0
            )
        )
    }

    private func makeBuffer(
        maximumAge: TimeInterval = 300
    ) throws -> LocationHistoryBuffer {
        LocationHistoryBuffer(
            configuration:
                try LocationHistoryConfiguration(
                    maximumSampleCount: 100,
                    maximumSampleAge: maximumAge
                )
        )
    }
}
