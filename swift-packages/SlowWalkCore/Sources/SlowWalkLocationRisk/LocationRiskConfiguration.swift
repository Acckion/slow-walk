import Foundation

public enum LocationRiskConfigurationError:
    Error,
    Sendable,
    Equatable
{
    case nonPositiveThreshold
    case negativeThreshold
    case invalidSampleCount
}

/// DEMO LOCATION SAFETY CONFIGURATION
/// NOT A PRODUCTION NAVIGATION STANDARD
public struct LocationRiskConfiguration:
    Sendable,
    Equatable,
    Hashable
{
    public static let notices = [
        "DEMO LOCATION SAFETY CONFIGURATION",
        "NOT A PRODUCTION NAVIGATION STANDARD",
    ]

    public let maximumSampleAge: TimeInterval
    public let futureTimestampTolerance: TimeInterval
    public let excellentAccuracyMeters: Double
    public let goodAccuracyMeters: Double
    public let maximumUsableAccuracyMeters: Double
    public let maximumPlausibleSpeedMetersPerSecond: Double
    public let minimumSamplesForAssessment: Int
    public let approachingBufferMeters: Double
    public let prolongedStopRadiusMeters: Double
    public let prolongedStopDuration: TimeInterval
    public let prolongedStopMinimumDistanceMeters: Double
    public let prolongedStopMinimumSamples: Int
    public let movingAwayMinimumSamples: Int
    public let movingAwayMinimumDuration: TimeInterval
    public let movingAwayMinimumDistanceIncreaseMeters: Double
    public let movingAwayNoiseToleranceMeters: Double
    public let redSignalCount: Int

    public init(
        maximumSampleAge: TimeInterval,
        futureTimestampTolerance: TimeInterval,
        excellentAccuracyMeters: Double,
        goodAccuracyMeters: Double,
        maximumUsableAccuracyMeters: Double,
        maximumPlausibleSpeedMetersPerSecond: Double,
        minimumSamplesForAssessment: Int,
        approachingBufferMeters: Double,
        prolongedStopRadiusMeters: Double,
        prolongedStopDuration: TimeInterval,
        prolongedStopMinimumDistanceMeters: Double,
        prolongedStopMinimumSamples: Int,
        movingAwayMinimumSamples: Int,
        movingAwayMinimumDuration: TimeInterval,
        movingAwayMinimumDistanceIncreaseMeters: Double,
        movingAwayNoiseToleranceMeters: Double,
        redSignalCount: Int
    ) throws {
        let positiveValues = [
            maximumSampleAge,
            excellentAccuracyMeters,
            goodAccuracyMeters,
            maximumUsableAccuracyMeters,
            maximumPlausibleSpeedMetersPerSecond,
            approachingBufferMeters,
            prolongedStopRadiusMeters,
            prolongedStopDuration,
            prolongedStopMinimumDistanceMeters,
            movingAwayMinimumDuration,
            movingAwayMinimumDistanceIncreaseMeters,
        ]
        guard positiveValues.allSatisfy({
            $0.isFinite && $0 > 0
        }) else {
            throw LocationRiskConfigurationError
                .nonPositiveThreshold
        }
        guard futureTimestampTolerance.isFinite,
              futureTimestampTolerance >= 0,
              movingAwayNoiseToleranceMeters.isFinite,
              movingAwayNoiseToleranceMeters >= 0
        else {
            throw LocationRiskConfigurationError
                .negativeThreshold
        }
        guard minimumSamplesForAssessment > 0,
              prolongedStopMinimumSamples > 1,
              movingAwayMinimumSamples > 1,
              redSignalCount > 1
        else {
            throw LocationRiskConfigurationError
                .invalidSampleCount
        }
        guard excellentAccuracyMeters <= goodAccuracyMeters,
              goodAccuracyMeters
                <= maximumUsableAccuracyMeters
        else {
            throw LocationRiskConfigurationError
                .nonPositiveThreshold
        }

        self.maximumSampleAge = maximumSampleAge
        self.futureTimestampTolerance =
            futureTimestampTolerance
        self.excellentAccuracyMeters =
            excellentAccuracyMeters
        self.goodAccuracyMeters = goodAccuracyMeters
        self.maximumUsableAccuracyMeters =
            maximumUsableAccuracyMeters
        self.maximumPlausibleSpeedMetersPerSecond =
            maximumPlausibleSpeedMetersPerSecond
        self.minimumSamplesForAssessment =
            minimumSamplesForAssessment
        self.approachingBufferMeters =
            approachingBufferMeters
        self.prolongedStopRadiusMeters =
            prolongedStopRadiusMeters
        self.prolongedStopDuration =
            prolongedStopDuration
        self.prolongedStopMinimumDistanceMeters =
            prolongedStopMinimumDistanceMeters
        self.prolongedStopMinimumSamples =
            prolongedStopMinimumSamples
        self.movingAwayMinimumSamples =
            movingAwayMinimumSamples
        self.movingAwayMinimumDuration =
            movingAwayMinimumDuration
        self.movingAwayMinimumDistanceIncreaseMeters =
            movingAwayMinimumDistanceIncreaseMeters
        self.movingAwayNoiseToleranceMeters =
            movingAwayNoiseToleranceMeters
        self.redSignalCount = redSignalCount
    }

    public static let demo = LocationRiskConfiguration(
        validatedMaximumSampleAge: 15 * 60,
        futureTimestampTolerance: 5,
        excellentAccuracyMeters: 20,
        goodAccuracyMeters: 50,
        maximumUsableAccuracyMeters: 100,
        maximumPlausibleSpeedMetersPerSecond: 70,
        minimumSamplesForAssessment: 2,
        approachingBufferMeters: 150,
        prolongedStopRadiusMeters: 50,
        prolongedStopDuration: 10 * 60,
        prolongedStopMinimumDistanceMeters: 250,
        prolongedStopMinimumSamples: 3,
        movingAwayMinimumSamples: 3,
        movingAwayMinimumDuration: 2 * 60,
        movingAwayMinimumDistanceIncreaseMeters: 25,
        movingAwayNoiseToleranceMeters: 5,
        redSignalCount: 2
    )

    private init(
        validatedMaximumSampleAge: TimeInterval,
        futureTimestampTolerance: TimeInterval,
        excellentAccuracyMeters: Double,
        goodAccuracyMeters: Double,
        maximumUsableAccuracyMeters: Double,
        maximumPlausibleSpeedMetersPerSecond: Double,
        minimumSamplesForAssessment: Int,
        approachingBufferMeters: Double,
        prolongedStopRadiusMeters: Double,
        prolongedStopDuration: TimeInterval,
        prolongedStopMinimumDistanceMeters: Double,
        prolongedStopMinimumSamples: Int,
        movingAwayMinimumSamples: Int,
        movingAwayMinimumDuration: TimeInterval,
        movingAwayMinimumDistanceIncreaseMeters: Double,
        movingAwayNoiseToleranceMeters: Double,
        redSignalCount: Int
    ) {
        maximumSampleAge = validatedMaximumSampleAge
        self.futureTimestampTolerance =
            futureTimestampTolerance
        self.excellentAccuracyMeters =
            excellentAccuracyMeters
        self.goodAccuracyMeters = goodAccuracyMeters
        self.maximumUsableAccuracyMeters =
            maximumUsableAccuracyMeters
        self.maximumPlausibleSpeedMetersPerSecond =
            maximumPlausibleSpeedMetersPerSecond
        self.minimumSamplesForAssessment =
            minimumSamplesForAssessment
        self.approachingBufferMeters =
            approachingBufferMeters
        self.prolongedStopRadiusMeters =
            prolongedStopRadiusMeters
        self.prolongedStopDuration =
            prolongedStopDuration
        self.prolongedStopMinimumDistanceMeters =
            prolongedStopMinimumDistanceMeters
        self.prolongedStopMinimumSamples =
            prolongedStopMinimumSamples
        self.movingAwayMinimumSamples =
            movingAwayMinimumSamples
        self.movingAwayMinimumDuration =
            movingAwayMinimumDuration
        self.movingAwayMinimumDistanceIncreaseMeters =
            movingAwayMinimumDistanceIncreaseMeters
        self.movingAwayNoiseToleranceMeters =
            movingAwayNoiseToleranceMeters
        self.redSignalCount = redSignalCount
    }
}
