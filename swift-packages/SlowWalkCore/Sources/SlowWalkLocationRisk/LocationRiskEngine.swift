import Foundation
import SlowWalkDomain

public enum LocationRiskAssessmentError:
    Error,
    Sendable,
    Equatable
{
    case invalidDestination
}

public protocol LocationRiskAssessing: Sendable {
    func assess(
        destination: Destination,
        recentSamples: [LocationSample]
    ) throws -> LocationAssessment
}

public struct LocationRiskEngine:
    LocationRiskAssessing,
    Sendable
{
    private let clock: any Clock
    private let configuration: LocationRiskConfiguration
    private let dataQualityAssessor:
        any LocationDataQualityAssessing
    private let distanceCalculator: any DistanceCalculating
    private let geofenceEvaluator: GeofenceEvaluator
    private let prolongedStopEvaluator: ProlongedStopEvaluator
    private let movingAwayEvaluator: MovingAwayEvaluator

    public init(
        clock: any Clock,
        configuration: LocationRiskConfiguration = .demo,
        dataQualityAssessor:
            (any LocationDataQualityAssessing)? = nil,
        distanceCalculator: any DistanceCalculating =
            HaversineDistanceCalculator()
    ) {
        self.clock = clock
        self.configuration = configuration
        self.distanceCalculator = distanceCalculator
        self.dataQualityAssessor =
            dataQualityAssessor
            ?? LocationDataQualityAssessor(
                configuration: configuration,
                distanceCalculator: distanceCalculator
            )
        geofenceEvaluator = GeofenceEvaluator(
            configuration: configuration
        )
        prolongedStopEvaluator = ProlongedStopEvaluator(
            configuration: configuration,
            distanceCalculator: distanceCalculator
        )
        movingAwayEvaluator = MovingAwayEvaluator(
            configuration: configuration,
            distanceCalculator: distanceCalculator
        )
    }

    public func assess(
        destination: Destination,
        recentSamples: [LocationSample]
    ) throws -> LocationAssessment {
        guard destination.geofenceRadiusMeters.isFinite,
              destination.geofenceRadiusMeters > 0,
              (try? distanceCalculator.distance(
                  from: destination.point,
                  to: destination.point
              )) != nil
        else {
            throw LocationRiskAssessmentError
                .invalidDestination
        }

        let assessedAt = clock.now()
        let quality = dataQualityAssessor.assess(
            samples: recentSamples,
            relativeTo: assessedAt
        )
        let usableSamples = quality.usableSampleIndices
            .map { recentSamples[$0] }
            .sorted { $0.recordedAt < $1.recordedAt }
        let latestSample = usableSamples.last
        let distance = latestSample.flatMap {
            try? distanceCalculator.distance(
                from: $0.point,
                to: destination.point
            )
        }
        let geofenceState = distance.map {
            geofenceEvaluator.evaluate(
                distanceMeters: $0,
                destinationRadiusMeters:
                    destination.geofenceRadiusMeters
            )
        } ?? .outside

        var ratedReasons = qualityReasons(quality)
        let prolongedStop = prolongedStopEvaluator
            .evaluate(
                samples: usableSamples,
                destination: destination
            )
        let movingAway = movingAwayEvaluator.evaluate(
            samples: usableSamples,
            destination: destination
        )

        if prolongedStop.isDetected {
            ratedReasons.append(
                RatedLocationReason(
                    level: .orange,
                    reason: LocationRiskReason(
                        code: .prolongedStop,
                        message:
                            "A prolonged stop was detected away from the destination.",
                        evidence:
                            "The demo stop-duration and spread thresholds were both met.",
                        ruleIdentifier:
                            "location-prolonged-stop"
                    )
                )
            )
        }
        if movingAway.isDetected {
            ratedReasons.append(
                RatedLocationReason(
                    level: .orange,
                    reason: LocationRiskReason(
                        code: .movingAway,
                        message:
                            "Several reliable samples moved farther from the destination.",
                        evidence:
                            "Consecutive distance increases exceeded the demo noise tolerance.",
                        ruleIdentifier:
                            "location-moving-away"
                    )
                )
            )
        }

        if geofenceState == .inside,
           quality.status == .valid {
            ratedReasons.append(
                RatedLocationReason(
                    level: .green,
                    reason: LocationRiskReason(
                        code: .arrivedAtDestination,
                        message:
                            "The latest reliable sample is inside the destination geofence.",
                        evidence:
                            "Distance is within the configured destination radius.",
                        ruleIdentifier:
                            "location-destination-geofence"
                    )
                )
            )
        } else if ratedReasons.isEmpty {
            ratedReasons.append(
                RatedLocationReason(
                    level: .green,
                    reason: LocationRiskReason(
                        code: .progressingTowardDestination,
                        message:
                            geofenceState == .approaching
                            ? "The latest reliable sample is approaching the destination."
                            : "No demo location-risk rule was triggered.",
                        evidence:
                            "Recent reliable samples did not meet stop or moving-away thresholds.",
                        ruleIdentifier:
                            "location-normal-progress"
                    )
                )
            )
        }

        let orangeSignalCount = ratedReasons.filter {
            $0.level == .orange
        }.count
        if orangeSignalCount >= configuration.redSignalCount {
            ratedReasons.append(
                RatedLocationReason(
                    level: .red,
                    reason: LocationRiskReason(
                        code: .multipleHighRiskSignals,
                        message:
                            "Multiple high-risk demo location signals were detected.",
                        evidence:
                            "At least two independent orange-level rules were retained.",
                        ruleIdentifier:
                            "location-multiple-high-risk-signals"
                    )
                )
            )
        }

        let level = ratedReasons.map(\.level).max()
            ?? .yellow
        let reasons = ratedReasons.map(\.reason).sorted {
            if $0.code.rawValue != $1.code.rawValue {
                return $0.code.rawValue < $1.code.rawValue
            }
            return $0.ruleIdentifier < $1.ruleIdentifier
        }
        let actions = recommendedActions(
            for: level,
            geofenceState: geofenceState
        )

        return LocationAssessment(
            level: level,
            reasons: reasons,
            recommendedActions: actions,
            assessedAt: assessedAt,
            dataQuality: quality,
            distanceToDestinationMeters: distance,
            isInsideDestinationGeofence:
                geofenceState == .inside,
            requiresUserAttention: level != .green,
            requiresFamilyAttention: level == .red
        )
    }

    private func qualityReasons(
        _ quality: LocationDataQuality
    ) -> [RatedLocationReason] {
        var seen = Set<LocationRiskReasonCode>()
        var values = [RatedLocationReason]()
        for issue in quality.issues {
            let rated = ratedReason(for: issue)
            guard seen.insert(rated.reason.code).inserted else {
                continue
            }
            values.append(rated)
        }
        if values.isEmpty, quality.status != .valid {
            values.append(
                RatedLocationReason(
                    level: .yellow,
                    reason: LocationRiskReason(
                        code: .insufficientLocationHistory,
                        message:
                            "Location history is insufficient for a deterministic green result.",
                        evidence:
                            "The configured minimum reliable sample count was not met.",
                        ruleIdentifier:
                            "location-history-sufficiency"
                    )
                )
            )
        }
        return values
    }

    private func ratedReason(
        for issue: LocationDataQualityIssue
    ) -> RatedLocationReason {
        switch issue.code {
        case .staleSample:
            return RatedLocationReason(
                level: .yellow,
                reason: LocationRiskReason(
                    code: .locationDataStale,
                    message:
                        "One or more location samples are stale.",
                    evidence:
                        "A sample exceeded the demo recency threshold.",
                    ruleIdentifier: issue.ruleIdentifier
                )
            )
        case .accuracyMissing,
             .accuracyInvalid,
             .accuracyInsufficient:
            return RatedLocationReason(
                level: .yellow,
                reason: LocationRiskReason(
                    code: .locationAccuracyInsufficient,
                    message:
                        "Location accuracy is insufficient for a deterministic green result.",
                    evidence:
                        "Horizontal accuracy was missing, invalid, or above the demo threshold.",
                    ruleIdentifier: issue.ruleIdentifier
                )
            )
        case .insufficientSamples:
            return RatedLocationReason(
                level: .yellow,
                reason: LocationRiskReason(
                    code: .insufficientLocationHistory,
                    message:
                        "Location history is insufficient for a deterministic green result.",
                    evidence:
                        "The configured minimum reliable sample count was not met.",
                    ruleIdentifier: issue.ruleIdentifier
                )
            )
        case .samplesOutOfOrder:
            return RatedLocationReason(
                level: .orange,
                reason: LocationRiskReason(
                    code: .samplesOutOfOrder,
                    message:
                        "Location samples are not in chronological order.",
                    evidence:
                        "At least one recordedAt value precedes the previous sample.",
                    ruleIdentifier: issue.ruleIdentifier
                )
            )
        case .implausibleJump:
            return RatedLocationReason(
                level: .orange,
                reason: LocationRiskReason(
                    code: .implausibleLocationJump,
                    message:
                        "An implausible instantaneous location change was detected.",
                    evidence:
                        "Calculated speed exceeded the demo plausibility threshold.",
                    ruleIdentifier: issue.ruleIdentifier
                )
            )
        case .invalidLatitude,
             .invalidLongitude,
             .nonFiniteCoordinate,
             .futureSample,
             .invalidSpeed:
            return RatedLocationReason(
                level: .orange,
                reason: LocationRiskReason(
                    code: .invalidLocationSample,
                    message:
                        "A structurally invalid location sample was detected.",
                    evidence:
                        "A coordinate, timestamp, or speed field failed validation.",
                    ruleIdentifier: issue.ruleIdentifier
                )
            )
        }
    }

    private func recommendedActions(
        for level: LocationRiskLevel,
        geofenceState: GeofenceState
    ) -> [LocationRecommendedAction] {
        switch level {
        case .green:
            return geofenceState == .inside
                ? [.confirmArrival]
                : [.continueTowardDestination]
        case .yellow:
            return [
                .stopInSafePlace,
                .recheckLocation,
            ]
        case .orange:
            return [
                .stopInSafePlace,
                .confirmDirection,
                .recheckLocation,
            ]
        case .red:
            return [
                .stopInSafePlace,
                .contactFamilyOrStaff,
            ]
        }
    }
}

private struct RatedLocationReason: Sendable {
    let level: LocationRiskLevel
    let reason: LocationRiskReason
}
