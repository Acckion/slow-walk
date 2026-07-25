import Foundation
import SlowWalkLocationRisk

public struct LocationHistoryConfiguration:
    Sendable,
    Equatable,
    Hashable
{
    public let maximumSampleCount: Int
    public let maximumSampleAge: TimeInterval

    public init(
        maximumSampleCount: Int,
        maximumSampleAge: TimeInterval
    ) throws {
        guard maximumSampleCount > 0 else {
            throw ClientCoreConfigurationError
                .invalidMaximumSampleCount
        }
        guard maximumSampleAge.isFinite,
              maximumSampleAge > 0
        else {
            throw ClientCoreConfigurationError
                .invalidMaximumSampleAge
        }
        self.maximumSampleCount = maximumSampleCount
        self.maximumSampleAge = maximumSampleAge
    }
}
/// Privacy-bounded, deterministic location history storage.
public actor LocationHistoryBuffer {
    public let configuration:
        LocationHistoryConfiguration

    private var samples: [LocationSample]

    public init(
        configuration:
            LocationHistoryConfiguration
    ) {
        self.configuration = configuration
        samples = []
    }

    public func append(
        _ sample: LocationSample,
        asOf referenceDate: Date
    ) {
        samples = BoundedLocationSamples.normalize(
            samples + [sample],
            asOf: referenceDate,
            configuration: configuration
        )
    }

    public func append(
        contentsOf newSamples: [LocationSample],
        asOf referenceDate: Date
    ) {
        samples = BoundedLocationSamples.normalize(
            samples + newSamples,
            asOf: referenceDate,
            configuration: configuration
        )
    }

    public func recentSamples(
        asOf referenceDate: Date
    ) -> [LocationSample] {
        samples = BoundedLocationSamples.normalize(
            samples,
            asOf: referenceDate,
            configuration: configuration
        )
        return samples
    }

    public func clear() {
        samples.removeAll(keepingCapacity: false)
    }
}

enum BoundedLocationSamples {
    static func normalize(
        _ samples: [LocationSample],
        asOf referenceDate: Date,
        configuration:
            LocationHistoryConfiguration
    ) -> [LocationSample] {
        let cutoff = referenceDate.addingTimeInterval(
            -configuration.maximumSampleAge
        )
        let sorted = samples
            .filter { $0.recordedAt >= cutoff }
            .sorted(by: isOrderedBefore)

        var deduplicated: [LocationSample] = []
        deduplicated.reserveCapacity(sorted.count)
        for sample in sorted {
            if deduplicated.last != sample {
                deduplicated.append(sample)
            }
        }

        if deduplicated.count
            > configuration.maximumSampleCount
        {
            return Array(
                deduplicated.suffix(
                    configuration.maximumSampleCount
                )
            )
        }
        return deduplicated
    }

    private static func isOrderedBefore(
        _ lhs: LocationSample,
        _ rhs: LocationSample
    ) -> Bool {
        if lhs.recordedAt != rhs.recordedAt {
            return lhs.recordedAt < rhs.recordedAt
        }

        for (left, right) in [
            (
                lhs.point.latitude.bitPattern,
                rhs.point.latitude.bitPattern
            ),
            (
                lhs.point.longitude.bitPattern,
                rhs.point.longitude.bitPattern
            ),
        ] where left != right {
            return left < right
        }

        let accuracyComparison = compare(
            lhs.horizontalAccuracyMeters,
            rhs.horizontalAccuracyMeters
        )
        if accuracyComparison != 0 {
            return accuracyComparison < 0
        }

        let speedComparison = compare(
            lhs.speedMetersPerSecond,
            rhs.speedMetersPerSecond
        )
        if speedComparison != 0 {
            return speedComparison < 0
        }

        switch (lhs.source, rhs.source) {
        case let (left?, right?):
            return left < right
        case (nil, _?):
            return true
        case (_?, nil), (nil, nil):
            return false
        }
    }

    private static func compare(
        _ lhs: Double?,
        _ rhs: Double?
    ) -> Int {
        switch (lhs, rhs) {
        case let (left?, right?):
            if left.bitPattern == right.bitPattern {
                return 0
            }
            return left.bitPattern < right.bitPattern
                ? -1
                : 1
        case (nil, nil):
            return 0
        case (nil, _?):
            return -1
        case (_?, nil):
            return 1
        }
    }
}
