import Foundation

public enum ResolverConfigurationError: Error, Sendable, Equatable {
    case scoreOutsideUnitInterval(field: String)
    case invalidScoreOrdering
    case invalidAmbiguityScoreGap
    case nonPositiveApproximateLength
    case emptyMatcherVersion
}

/// Deterministic thresholds for medicine-name resolution.
///
/// These values tune string matching only. They are not clinical thresholds.
public struct ResolverConfiguration: Sendable, Equatable, Hashable {
    public let minimumRecognitionConfidence: Double
    public let minimumCandidateScore: Double
    public let minimumResolvedScore: Double
    public let ambiguityScoreGap: Double
    public let minimumApproximateLength: Int
    public let matcherVersion: String
    public let canonicalExactScore: Double
    public let aliasExactScore: Double
    public let canonicalNormalizedScore: Double
    public let aliasNormalizedScore: Double
    public let approximateMaximumScore: Double
    public let approximateBaseScore: Double
    public let approximateRange: Double
    public let oneEditScore: Double

    public init(
        minimumRecognitionConfidence: Double,
        minimumCandidateScore: Double,
        minimumResolvedScore: Double,
        ambiguityScoreGap: Double,
        minimumApproximateLength: Int,
        matcherVersion: String,
        canonicalExactScore: Double,
        aliasExactScore: Double,
        canonicalNormalizedScore: Double,
        aliasNormalizedScore: Double,
        approximateMaximumScore: Double,
        approximateBaseScore: Double,
        approximateRange: Double,
        oneEditScore: Double
    ) throws {
        let scores = [
            ("minimumRecognitionConfidence", minimumRecognitionConfidence),
            ("minimumCandidateScore", minimumCandidateScore),
            ("minimumResolvedScore", minimumResolvedScore),
            ("canonicalExactScore", canonicalExactScore),
            ("aliasExactScore", aliasExactScore),
            ("canonicalNormalizedScore", canonicalNormalizedScore),
            ("aliasNormalizedScore", aliasNormalizedScore),
            ("approximateMaximumScore", approximateMaximumScore),
            ("approximateBaseScore", approximateBaseScore),
            ("approximateRange", approximateRange),
            ("oneEditScore", oneEditScore),
        ]
        for (field, value) in scores
        where !value.isFinite || !(0 ... 1).contains(value) {
            throw ResolverConfigurationError.scoreOutsideUnitInterval(
                field: field
            )
        }
        guard minimumCandidateScore <= minimumResolvedScore else {
            throw ResolverConfigurationError.invalidScoreOrdering
        }
        guard approximateBaseScore <= approximateMaximumScore,
              approximateMaximumScore < minimumResolvedScore,
              oneEditScore < minimumResolvedScore,
              canonicalExactScore >= minimumResolvedScore,
              aliasExactScore >= minimumResolvedScore,
              canonicalNormalizedScore >= minimumResolvedScore,
              aliasNormalizedScore >= minimumResolvedScore else {
            throw ResolverConfigurationError.invalidScoreOrdering
        }
        guard ambiguityScoreGap.isFinite,
              ambiguityScoreGap >= 0,
              ambiguityScoreGap <= 1 else {
            throw ResolverConfigurationError.invalidAmbiguityScoreGap
        }
        guard minimumApproximateLength > 0 else {
            throw ResolverConfigurationError.nonPositiveApproximateLength
        }
        guard !matcherVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw ResolverConfigurationError.emptyMatcherVersion
        }

        self.init(
            validatedMinimumRecognitionConfidence:
                minimumRecognitionConfidence,
            minimumCandidateScore: minimumCandidateScore,
            minimumResolvedScore: minimumResolvedScore,
            ambiguityScoreGap: ambiguityScoreGap,
            minimumApproximateLength: minimumApproximateLength,
            matcherVersion: matcherVersion,
            canonicalExactScore: canonicalExactScore,
            aliasExactScore: aliasExactScore,
            canonicalNormalizedScore: canonicalNormalizedScore,
            aliasNormalizedScore: aliasNormalizedScore,
            approximateMaximumScore: approximateMaximumScore,
            approximateBaseScore: approximateBaseScore,
            approximateRange: approximateRange,
            oneEditScore: oneEditScore
        )
    }

    public static let standard = ResolverConfiguration(
        validatedMinimumRecognitionConfidence: 0.75,
        minimumCandidateScore: 0.78,
        minimumResolvedScore: 0.92,
        ambiguityScoreGap: 0.04,
        minimumApproximateLength: 4,
        matcherVersion: "slowwalk-resolver-v1",
        canonicalExactScore: 1.0,
        aliasExactScore: 0.99,
        canonicalNormalizedScore: 0.96,
        aliasNormalizedScore: 0.94,
        approximateMaximumScore: 0.89,
        approximateBaseScore: 0.78,
        approximateRange: 0.11,
        oneEditScore: 0.86
    )

    private init(
        validatedMinimumRecognitionConfidence: Double,
        minimumCandidateScore: Double,
        minimumResolvedScore: Double,
        ambiguityScoreGap: Double,
        minimumApproximateLength: Int,
        matcherVersion: String,
        canonicalExactScore: Double,
        aliasExactScore: Double,
        canonicalNormalizedScore: Double,
        aliasNormalizedScore: Double,
        approximateMaximumScore: Double,
        approximateBaseScore: Double,
        approximateRange: Double,
        oneEditScore: Double
    ) {
        minimumRecognitionConfidence =
            validatedMinimumRecognitionConfidence
        self.minimumCandidateScore = minimumCandidateScore
        self.minimumResolvedScore = minimumResolvedScore
        self.ambiguityScoreGap = ambiguityScoreGap
        self.minimumApproximateLength = minimumApproximateLength
        self.matcherVersion = matcherVersion
        self.canonicalExactScore = canonicalExactScore
        self.aliasExactScore = aliasExactScore
        self.canonicalNormalizedScore = canonicalNormalizedScore
        self.aliasNormalizedScore = aliasNormalizedScore
        self.approximateMaximumScore = approximateMaximumScore
        self.approximateBaseScore = approximateBaseScore
        self.approximateRange = approximateRange
        self.oneEditScore = oneEditScore
    }
}
