import Foundation

struct ProgressTowardDestinationEvaluation: Sendable {
    let isDetected: Bool
    let isDeterminate: Bool
    let totalDistanceDecreaseMeters: Double?
    let consecutiveDecreases: Int
}

struct ProgressTowardDestinationEvaluator: Sendable {
    private let configuration: LocationRiskConfiguration
    private let distanceCalculator: any DistanceCalculating

    init(
        configuration: LocationRiskConfiguration,
        distanceCalculator: any DistanceCalculating
    ) {
        self.configuration = configuration
        self.distanceCalculator = distanceCalculator
    }

    func evaluate(
        samples: [LocationSample],
        destination: Destination
    ) -> ProgressTowardDestinationEvaluation {
        let ordered = samples.sorted {
            $0.recordedAt < $1.recordedAt
        }
        guard ordered.count
            >= configuration.minimumSamplesForAssessment
        else {
            return ProgressTowardDestinationEvaluation(
                isDetected: false,
                isDeterminate: false,
                totalDistanceDecreaseMeters: nil,
                consecutiveDecreases: 0
            )
        }

        let distances = ordered.compactMap {
            try? distanceCalculator.distance(
                from: $0.point,
                to: destination.point
            )
        }
        guard distances.count == ordered.count,
              let first = distances.first,
              let last = distances.last
        else {
            return ProgressTowardDestinationEvaluation(
                isDetected: false,
                isDeterminate: false,
                totalDistanceDecreaseMeters: nil,
                consecutiveDecreases: 0
            )
        }

        var consecutiveDecreases = 0
        for index in 1 ..< distances.count {
            if distances[index - 1] - distances[index]
                > configuration
                .movingAwayNoiseToleranceMeters
            {
                consecutiveDecreases += 1
            }
        }
        let totalDecrease = first - last
        let requiredDecreases = distances.count - 1
        let isDetected =
            consecutiveDecreases == requiredDecreases
            && totalDecrease
            >= configuration
            .movingAwayMinimumDistanceIncreaseMeters

        return ProgressTowardDestinationEvaluation(
            isDetected: isDetected,
            isDeterminate: true,
            totalDistanceDecreaseMeters: totalDecrease,
            consecutiveDecreases: consecutiveDecreases
        )
    }
}

public struct ProlongedStopEvaluation:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let isDetected: Bool
    public let isDeterminate: Bool
    public let durationSeconds: TimeInterval
    public let maximumSpreadMeters: Double?
    public let distanceToDestinationMeters: Double?

    public init(
        isDetected: Bool,
        isDeterminate: Bool,
        durationSeconds: TimeInterval,
        maximumSpreadMeters: Double?,
        distanceToDestinationMeters: Double?
    ) {
        self.isDetected = isDetected
        self.isDeterminate = isDeterminate
        self.durationSeconds = durationSeconds
        self.maximumSpreadMeters = maximumSpreadMeters
        self.distanceToDestinationMeters =
            distanceToDestinationMeters
    }
}

public struct ProlongedStopEvaluator: Sendable {
    private let configuration: LocationRiskConfiguration
    private let distanceCalculator: any DistanceCalculating

    public init(
        configuration: LocationRiskConfiguration = .demo,
        distanceCalculator: any DistanceCalculating =
            HaversineDistanceCalculator()
    ) {
        self.configuration = configuration
        self.distanceCalculator = distanceCalculator
    }

    public func evaluate(
        samples: [LocationSample],
        destination: Destination
    ) -> ProlongedStopEvaluation {
        let ordered = samples.sorted {
            $0.recordedAt < $1.recordedAt
        }
        guard ordered.count
            >= configuration.prolongedStopMinimumSamples,
              let first = ordered.first,
              let last = ordered.last
        else {
            return ProlongedStopEvaluation(
                isDetected: false,
                isDeterminate: false,
                durationSeconds: 0,
                maximumSpreadMeters: nil,
                distanceToDestinationMeters: nil
            )
        }

        let duration = last.recordedAt
            .timeIntervalSince(first.recordedAt)
        guard let spread = maximumSpread(in: ordered),
              let destinationDistance = try? distanceCalculator
                .distance(
                    from: last.point,
                    to: destination.point
                )
        else {
            return ProlongedStopEvaluation(
                isDetected: false,
                isDeterminate: false,
                durationSeconds: max(duration, 0),
                maximumSpreadMeters: nil,
                distanceToDestinationMeters: nil
            )
        }

        let hasEnoughDuration =
            duration >= configuration.prolongedStopDuration
        let isDetected = hasEnoughDuration
            && spread
            <= configuration.prolongedStopRadiusMeters
            && destinationDistance
            > configuration
            .prolongedStopMinimumDistanceMeters
        return ProlongedStopEvaluation(
            isDetected: isDetected,
            isDeterminate: hasEnoughDuration,
            durationSeconds: max(duration, 0),
            maximumSpreadMeters: spread,
            distanceToDestinationMeters: destinationDistance
        )
    }

    private func maximumSpread(
        in samples: [LocationSample]
    ) -> Double? {
        var maximum = 0.0
        for leftIndex in samples.indices {
            for rightIndex in samples.indices
                where rightIndex > leftIndex {
                guard let distance = try? distanceCalculator
                    .distance(
                        from: samples[leftIndex].point,
                        to: samples[rightIndex].point
                    )
                else {
                    return nil
                }
                maximum = max(maximum, distance)
            }
        }
        return maximum
    }
}

public struct MovingAwayEvaluation:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let isDetected: Bool
    public let isDeterminate: Bool
    public let durationSeconds: TimeInterval
    public let totalDistanceIncreaseMeters: Double?
    public let consecutiveIncreases: Int

    public init(
        isDetected: Bool,
        isDeterminate: Bool,
        durationSeconds: TimeInterval,
        totalDistanceIncreaseMeters: Double?,
        consecutiveIncreases: Int
    ) {
        self.isDetected = isDetected
        self.isDeterminate = isDeterminate
        self.durationSeconds = durationSeconds
        self.totalDistanceIncreaseMeters =
            totalDistanceIncreaseMeters
        self.consecutiveIncreases = consecutiveIncreases
    }
}

public struct MovingAwayEvaluator: Sendable {
    private let configuration: LocationRiskConfiguration
    private let distanceCalculator: any DistanceCalculating

    public init(
        configuration: LocationRiskConfiguration = .demo,
        distanceCalculator: any DistanceCalculating =
            HaversineDistanceCalculator()
    ) {
        self.configuration = configuration
        self.distanceCalculator = distanceCalculator
    }

    public func evaluate(
        samples: [LocationSample],
        destination: Destination
    ) -> MovingAwayEvaluation {
        let ordered = samples.sorted {
            $0.recordedAt < $1.recordedAt
        }
        guard ordered.count
            >= configuration.movingAwayMinimumSamples,
              let first = ordered.first,
              let last = ordered.last
        else {
            return MovingAwayEvaluation(
                isDetected: false,
                isDeterminate: false,
                durationSeconds: 0,
                totalDistanceIncreaseMeters: nil,
                consecutiveIncreases: 0
            )
        }

        let duration = last.recordedAt
            .timeIntervalSince(first.recordedAt)
        guard duration
            >= configuration.movingAwayMinimumDuration
        else {
            return MovingAwayEvaluation(
                isDetected: false,
                isDeterminate: false,
                durationSeconds: max(duration, 0),
                totalDistanceIncreaseMeters: nil,
                consecutiveIncreases: 0
            )
        }

        let distances = ordered.compactMap {
            try? distanceCalculator.distance(
                from: $0.point,
                to: destination.point
            )
        }
        guard distances.count == ordered.count,
              let startDistance = distances.first,
              let endDistance = distances.last
        else {
            return MovingAwayEvaluation(
                isDetected: false,
                isDeterminate: false,
                durationSeconds: duration,
                totalDistanceIncreaseMeters: nil,
                consecutiveIncreases: 0
            )
        }

        var consecutiveIncreases = 0
        for index in 1 ..< distances.count {
            if distances[index] - distances[index - 1]
                > configuration
                .movingAwayNoiseToleranceMeters {
                consecutiveIncreases += 1
            }
        }
        let requiredIncreases =
            configuration.movingAwayMinimumSamples - 1
        let totalIncrease = endDistance - startDistance
        let isDetected =
            consecutiveIncreases >= requiredIncreases
            && totalIncrease
            >= configuration
            .movingAwayMinimumDistanceIncreaseMeters

        return MovingAwayEvaluation(
            isDetected: isDetected,
            isDeterminate: true,
            durationSeconds: duration,
            totalDistanceIncreaseMeters: totalIncrease,
            consecutiveIncreases: consecutiveIncreases
        )
    }
}
