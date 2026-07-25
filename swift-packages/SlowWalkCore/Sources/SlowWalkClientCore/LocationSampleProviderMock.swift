import Foundation
import SlowWalkLocationRisk

public actor MockLocationSampleProvider:
    LocationSampleProviding
{
    private let buffer: LocationHistoryBuffer
    private var status: LocationSamplingStatus
    private var sampling = false

    public init(
        configuration:
            LocationHistoryConfiguration,
        status: LocationSamplingStatus
    ) {
        buffer = LocationHistoryBuffer(
            configuration: configuration
        )
        self.status = status
    }

    public func startSampling() async throws {
        try Task.checkCancellation()
        guard status.availability == .available,
              status.authorization == .authorized
        else {
            throw ClientTransportError.unavailable
        }
        sampling = true
    }

    public func stopSampling() async {
        sampling = false
    }

    public func recentSamples(
        asOf referenceDate: Date
    ) async -> [LocationSample] {
        await buffer.recentSamples(
            asOf: referenceDate
        )
    }

    public func clearHistory() async {
        await buffer.clear()
    }

    public func currentStatus() async
        -> LocationSamplingStatus
    {
        status
    }

    public func setStatus(
        _ status: LocationSamplingStatus
    ) {
        self.status = status
    }

    public func append(
        _ sample: LocationSample,
        asOf referenceDate: Date
    ) async {
        await buffer.append(
            sample,
            asOf: referenceDate
        )
    }

    public func append(
        contentsOf samples: [LocationSample],
        asOf referenceDate: Date
    ) async {
        await buffer.append(
            contentsOf: samples,
            asOf: referenceDate
        )
    }

    public func isSampling() -> Bool {
        sampling
    }
}
