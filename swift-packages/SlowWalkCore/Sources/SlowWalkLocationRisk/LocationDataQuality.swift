import Foundation

public protocol LocationDataQualityAssessing: Sendable {
    func assess(
        samples: [LocationSample],
        relativeTo referenceDate: Date
    ) -> LocationDataQuality
}

public struct LocationDataQualityAssessor:
    LocationDataQualityAssessing,
    Sendable
{
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

    public func assess(
        samples: [LocationSample],
        relativeTo referenceDate: Date
    ) -> LocationDataQuality {
        var issues = [LocationDataQualityIssue]()
        var excludedIndices = Set<Int>()
        var accuracyValues = [LocationAccuracy]()

        for (index, sample) in samples.enumerated() {
            validatePoint(
                sample.point,
                sampleIndex: index,
                issues: &issues,
                excludedIndices: &excludedIndices
            )
            validateTimestamp(
                sample.recordedAt,
                sampleIndex: index,
                relativeTo: referenceDate,
                issues: &issues,
                excludedIndices: &excludedIndices
            )
            accuracyValues.append(
                validateAccuracy(
                    sample.horizontalAccuracyMeters,
                    sampleIndex: index,
                    issues: &issues,
                    excludedIndices: &excludedIndices
                )
            )
            validateSpeed(
                sample.speedMetersPerSecond,
                sampleIndex: index,
                issues: &issues,
                excludedIndices: &excludedIndices
            )

            if index > 0,
               sample.recordedAt
                < samples[index - 1].recordedAt {
                issues.append(
                    issue(
                        code: .samplesOutOfOrder,
                        message:
                            "Location samples must be ordered by recordedAt.",
                        sampleIndex: index,
                        severity: .error,
                        rule: "location-sample-order"
                    )
                )
                excludedIndices.insert(index)
            }
        }

        excludeImplausibleJumps(
            samples: samples,
            excludedIndices: &excludedIndices,
            issues: &issues
        )

        var usableIndices = samples.indices.filter {
            !excludedIndices.contains($0)
        }
        usableIndices.sort {
            samples[$0].recordedAt
                < samples[$1].recordedAt
        }

        if usableIndices.count
            < configuration.minimumSamplesForAssessment {
            issues.append(
                issue(
                    code: .insufficientSamples,
                    message:
                        "More recent, reliable location samples are required.",
                    sampleIndex: nil,
                    severity: .warning,
                    rule: "location-history-sufficiency"
                )
            )
        }

        let sortedIssues = issues.sorted(by: Self.issueOrder)
        let status: LocationDataQualityStatus
        if sortedIssues.contains(where: {
            $0.severity == .error
        }) {
            status = .invalid
        } else if usableIndices.count
            < configuration.minimumSamplesForAssessment {
            status = .insufficient
        } else if sortedIssues.isEmpty {
            status = .valid
        } else {
            status = .warning
        }

        return LocationDataQuality(
            status: status,
            accuracy: worstAccuracy(in: accuracyValues),
            issues: sortedIssues,
            usableSampleIndices: usableIndices,
            configurationNotices:
                LocationRiskConfiguration.notices
        )
    }

    private func validatePoint(
        _ point: GeoPoint,
        sampleIndex: Int,
        issues: inout [LocationDataQualityIssue],
        excludedIndices: inout Set<Int>
    ) {
        guard point.latitude.isFinite,
              point.longitude.isFinite
        else {
            issues.append(
                issue(
                    code: .nonFiniteCoordinate,
                    message: "Location coordinates must be finite.",
                    sampleIndex: sampleIndex,
                    severity: .error,
                    rule: "location-coordinate-finite"
                )
            )
            excludedIndices.insert(sampleIndex)
            return
        }
        if !(-90 ... 90).contains(point.latitude) {
            issues.append(
                issue(
                    code: .invalidLatitude,
                    message:
                        "Latitude must be between -90 and 90.",
                    sampleIndex: sampleIndex,
                    severity: .error,
                    rule: "location-latitude-range"
                )
            )
            excludedIndices.insert(sampleIndex)
        }
        if !(-180 ... 180).contains(point.longitude) {
            issues.append(
                issue(
                    code: .invalidLongitude,
                    message:
                        "Longitude must be between -180 and 180.",
                    sampleIndex: sampleIndex,
                    severity: .error,
                    rule: "location-longitude-range"
                )
            )
            excludedIndices.insert(sampleIndex)
        }
    }

    private func validateTimestamp(
        _ recordedAt: Date,
        sampleIndex: Int,
        relativeTo referenceDate: Date,
        issues: inout [LocationDataQualityIssue],
        excludedIndices: inout Set<Int>
    ) {
        if recordedAt
            > referenceDate.addingTimeInterval(
                configuration.futureTimestampTolerance
            ) {
            issues.append(
                issue(
                    code: .futureSample,
                    message:
                        "The location sample timestamp is in the future.",
                    sampleIndex: sampleIndex,
                    severity: .error,
                    rule: "location-sample-future"
                )
            )
            excludedIndices.insert(sampleIndex)
        } else if referenceDate.timeIntervalSince(recordedAt)
            > configuration.maximumSampleAge {
            issues.append(
                issue(
                    code: .staleSample,
                    message:
                        "The location sample is older than the demo recency limit.",
                    sampleIndex: sampleIndex,
                    severity: .warning,
                    rule: "location-sample-recency"
                )
            )
            excludedIndices.insert(sampleIndex)
        }
    }

    private func validateAccuracy(
        _ accuracy: Double?,
        sampleIndex: Int,
        issues: inout [LocationDataQualityIssue],
        excludedIndices: inout Set<Int>
    ) -> LocationAccuracy {
        guard let accuracy else {
            issues.append(
                issue(
                    code: .accuracyMissing,
                    message:
                        "Horizontal accuracy is required for location risk assessment.",
                    sampleIndex: sampleIndex,
                    severity: .warning,
                    rule: "location-horizontal-accuracy"
                )
            )
            excludedIndices.insert(sampleIndex)
            return .missing
        }
        guard accuracy.isFinite, accuracy >= 0 else {
            issues.append(
                issue(
                    code: .accuracyInvalid,
                    message:
                        "Horizontal accuracy must be a finite non-negative value.",
                    sampleIndex: sampleIndex,
                    severity: .error,
                    rule: "location-horizontal-accuracy"
                )
            )
            excludedIndices.insert(sampleIndex)
            return .insufficient
        }
        if accuracy
            > configuration.maximumUsableAccuracyMeters {
            issues.append(
                issue(
                    code: .accuracyInsufficient,
                    message:
                        "Horizontal accuracy is insufficient for a deterministic assessment.",
                    sampleIndex: sampleIndex,
                    severity: .warning,
                    rule: "location-horizontal-accuracy"
                )
            )
            excludedIndices.insert(sampleIndex)
            return .insufficient
        }
        if accuracy <= configuration.excellentAccuracyMeters {
            return .excellent
        }
        if accuracy <= configuration.goodAccuracyMeters {
            return .good
        }
        return .reduced
    }

    private func validateSpeed(
        _ speed: Double?,
        sampleIndex: Int,
        issues: inout [LocationDataQualityIssue],
        excludedIndices: inout Set<Int>
    ) {
        guard let speed else {
            return
        }
        guard speed.isFinite, speed >= 0 else {
            issues.append(
                issue(
                    code: .invalidSpeed,
                    message:
                        "Speed must be a finite non-negative value when supplied.",
                    sampleIndex: sampleIndex,
                    severity: .error,
                    rule: "location-speed-format"
                )
            )
            excludedIndices.insert(sampleIndex)
            return
        }
        if speed
            > configuration
            .maximumPlausibleSpeedMetersPerSecond {
            issues.append(
                issue(
                    code: .implausibleJump,
                    message:
                        "Reported speed exceeds the demo plausibility threshold.",
                    sampleIndex: sampleIndex,
                    severity: .warning,
                    rule: "location-instantaneous-jump"
                )
            )
            excludedIndices.insert(sampleIndex)
        }
    }

    private func excludeImplausibleJumps(
        samples: [LocationSample],
        excludedIndices: inout Set<Int>,
        issues: inout [LocationDataQualityIssue]
    ) {
        guard samples.count > 1 else {
            return
        }
        for index in 1 ..< samples.count {
            let previousIndex = index - 1
            guard !excludedIndices.contains(previousIndex),
                  !excludedIndices.contains(index)
            else {
                continue
            }
            let elapsed = samples[index].recordedAt
                .timeIntervalSince(
                    samples[previousIndex].recordedAt
                )
            guard elapsed > 0,
                  let distance = try? distanceCalculator
                    .distance(
                        from: samples[previousIndex].point,
                        to: samples[index].point
                    )
            else {
                continue
            }
            let accuracyAllowance =
                (samples[previousIndex]
                    .horizontalAccuracyMeters ?? 0)
                + (samples[index]
                    .horizontalAccuracyMeters ?? 0)
            let speed = distance / elapsed
            if distance > accuracyAllowance,
               speed
                > configuration
                .maximumPlausibleSpeedMetersPerSecond {
                issues.append(
                    issue(
                        code: .implausibleJump,
                        message:
                            "Consecutive samples imply an implausible instantaneous jump.",
                        sampleIndex: index,
                        severity: .warning,
                        rule: "location-instantaneous-jump"
                    )
                )
                excludedIndices.insert(index)
            }
        }
    }

    private func worstAccuracy(
        in values: [LocationAccuracy]
    ) -> LocationAccuracy {
        values.max(by: {
            Self.accuracyRank($0)
                < Self.accuracyRank($1)
        }) ?? .missing
    }

    private static func accuracyRank(
        _ accuracy: LocationAccuracy
    ) -> Int {
        switch accuracy {
        case .excellent:
            0
        case .good:
            1
        case .reduced:
            2
        case .insufficient:
            3
        case .missing:
            4
        }
    }

    private func issue(
        code: LocationDataQualityIssueCode,
        message: String,
        sampleIndex: Int?,
        severity: LocationDataQualityIssueSeverity,
        rule: String
    ) -> LocationDataQualityIssue {
        LocationDataQualityIssue(
            code: code,
            message: message,
            sampleIndex: sampleIndex,
            severity: severity,
            ruleIdentifier: rule
        )
    }

    private static func issueOrder(
        _ lhs: LocationDataQualityIssue,
        _ rhs: LocationDataQualityIssue
    ) -> Bool {
        if lhs.code.rawValue != rhs.code.rawValue {
            return lhs.code.rawValue < rhs.code.rawValue
        }
        if lhs.sampleIndex != rhs.sampleIndex {
            return (lhs.sampleIndex ?? -1)
                < (rhs.sampleIndex ?? -1)
        }
        return lhs.ruleIdentifier < rhs.ruleIdentifier
    }
}
