import Foundation
import SlowWalkDomain

public protocol MedicineResolving: Sendable {
    func resolve(
        input: MedicineRecognitionInput,
        normalizedName: NormalizedMedicineName,
        medicines: [Medicine]
    ) -> MedicineResolution
}

/// Pure, deterministic resolver for a trusted in-memory medicine catalog.
public struct MedicineResolver: MedicineResolving, Sendable {
    private let normalizer: any MedicineNameNormalizing
    private let configuration: ResolverConfiguration

    public init(
        normalizer: any MedicineNameNormalizing = MedicineNameNormalizer(),
        configuration: ResolverConfiguration = .standard
    ) {
        self.normalizer = normalizer
        self.configuration = configuration
    }

    public func resolve(
        input: MedicineRecognitionInput,
        normalizedName: NormalizedMedicineName,
        medicines: [Medicine]
    ) -> MedicineResolution {
        let evidence = makeEvidence(
            input: input,
            normalizedName: normalizedName,
            medicines: medicines
        )
        guard !normalizedName.normalizedQuery.isEmpty else {
            return unresolved(
                status: .recognitionFailed,
                candidates: [],
                evidence: evidence
            )
        }

        let candidates = medicines
            .compactMap {
                makeCandidate(
                    medicine: $0,
                    input: input,
                    normalizedName: normalizedName
                )
            }
            .filter {
                $0.matchScore >= configuration.minimumCandidateScore
            }
            .sorted(by: Self.candidateOrder)

        guard !candidates.isEmpty else {
            return unresolved(
                status: .notFound,
                candidates: [],
                evidence: evidence
            )
        }

        guard let confidence = input.rawConfidence,
              confidence.isFinite,
              (0 ... 1).contains(confidence),
              confidence >= configuration.minimumRecognitionConfidence else {
            return unresolved(
                status: .insufficientEvidence,
                candidates: candidates,
                evidence: evidence
            )
        }

        guard let bestCandidate = candidates.first else {
            return unresolved(
                status: .notFound,
                candidates: [],
                evidence: evidence
            )
        }
        if candidates.dropFirst().contains(where: {
            bestCandidate.matchScore - $0.matchScore
                <= configuration.ambiguityScoreGap
        }) {
            return unresolved(
                status: .ambiguous,
                candidates: candidates,
                evidence: evidence
            )
        }

        guard bestCandidate.matchScore
                >= configuration.minimumResolvedScore else {
            return unresolved(
                status: .insufficientEvidence,
                candidates: candidates,
                evidence: evidence
            )
        }

        return MedicineResolution(
            status: .resolved,
            candidates: candidates,
            selectedMedicine: bestCandidate.medicine,
            evidence: evidence,
            requiresUserConfirmation: false
        )
    }

    private func unresolved(
        status: MedicineResolutionStatus,
        candidates: [MedicineCandidate],
        evidence: MedicineResolutionEvidence
    ) -> MedicineResolution {
        MedicineResolution(
            status: status,
            candidates: candidates,
            selectedMedicine: nil,
            evidence: evidence,
            requiresUserConfirmation: true
        )
    }

    private func makeCandidate(
        medicine: Medicine,
        input: MedicineRecognitionInput,
        normalizedName: NormalizedMedicineName
    ) -> MedicineCandidate? {
        let exactInputs = Set(
            input.recognizedTexts
                .map(normalizer.normalizeName)
                .filter { !$0.isEmpty }
        )
        let queryVariants = Set(
            ([normalizedName.normalizedQuery]
                + normalizedName.queryVariants)
                .filter { !$0.isEmpty }
        )
        let canonicalMatch = score(
            name: medicine.canonicalName,
            exactInputs: exactInputs,
            queryVariants: queryVariants,
            exactReason: .canonicalExact,
            normalizedReason: .canonicalNormalized,
            exactScore: configuration.canonicalExactScore,
            normalizedScore:
                configuration.canonicalNormalizedScore
        )
        let aliasMatches = medicine.aliases.compactMap { alias -> NameMatch? in
            guard let match = score(
                name: alias,
                exactInputs: exactInputs,
                queryVariants: queryVariants,
                exactReason: .aliasExact,
                normalizedReason: .aliasNormalized,
                exactScore: configuration.aliasExactScore,
                normalizedScore:
                    configuration.aliasNormalizedScore
            ) else {
                return nil
            }
            return NameMatch(
                score: match.score,
                reasons: match.reasons,
                matchedAlias: alias
            )
        }
        .sorted(by: Self.nameMatchOrder)

        let bestAliasMatch = aliasMatches.first
        guard canonicalMatch != nil || bestAliasMatch != nil else {
            return nil
        }

        let selectedMatch: NameMatch
        if let canonicalMatch,
           canonicalMatch.score >= (bestAliasMatch?.score ?? 0) {
            selectedMatch = canonicalMatch
        } else if let bestAliasMatch {
            selectedMatch = bestAliasMatch
        } else {
            return nil
        }

        let tiedReasons = [canonicalMatch, bestAliasMatch]
            .compactMap { $0 }
            .filter { $0.score == selectedMatch.score }
            .flatMap(\.reasons)
        let reasons = Self.stableReasons(tiedReasons)

        return MedicineCandidate(
            medicine: medicine,
            matchScore: selectedMatch.score,
            matchedAlias: selectedMatch.matchedAlias,
            matchReasons: reasons
        )
    }

    private func score(
        name: String,
        exactInputs: Set<String>,
        queryVariants: Set<String>,
        exactReason: MedicineMatchReason,
        normalizedReason: MedicineMatchReason,
        exactScore: Double,
        normalizedScore: Double
    ) -> NameMatch? {
        let exactName = normalizer.normalizeName(name)
        let normalizedCatalogName = normalizer.normalizeQuery(name)
        var bestScore = 0.0
        var reasons = [MedicineMatchReason]()

        if exactInputs.contains(exactName) {
            bestScore = exactScore
            reasons.append(exactReason)
        }
        if queryVariants.contains(normalizedCatalogName) {
            bestScore = max(bestScore, normalizedScore)
            reasons.append(normalizedReason)
        }

        let approximate = queryVariants
            .compactMap {
                conservativeApproximateScore(
                    query: $0,
                    catalogName: normalizedCatalogName
                )
            }
            .max()
        if let approximate {
            bestScore = max(bestScore, approximate)
            reasons.append(.conservativeApproximate)
        }

        guard bestScore > 0 else {
            return nil
        }
        return NameMatch(
            score: bestScore,
            reasons: Self.stableReasons(reasons),
            matchedAlias: nil
        )
    }

    private func conservativeApproximateScore(
        query: String,
        catalogName: String
    ) -> Double? {
        guard query != catalogName,
              query.count >= configuration.minimumApproximateLength,
              catalogName.count >= configuration.minimumApproximateLength else {
            return nil
        }

        let paddedQuery = " \(query) "
        let paddedCatalogName = " \(catalogName) "
        if paddedQuery.contains(paddedCatalogName)
            || paddedCatalogName.contains(paddedQuery) {
            let shorterCount = min(query.count, catalogName.count)
            let longerCount = max(query.count, catalogName.count)
            let lengthRatio = Double(shorterCount) / Double(longerCount)
            return min(
                configuration.approximateMaximumScore,
                configuration.approximateBaseScore
                    + (configuration.approximateRange * lengthRatio)
            )
        }

        guard isAtMostOneEditApart(query, catalogName) else {
            return nil
        }
        return configuration.oneEditScore
    }

    private func isAtMostOneEditApart(
        _ lhs: String,
        _ rhs: String
    ) -> Bool {
        let left = Array(lhs)
        let right = Array(rhs)
        guard abs(left.count - right.count) <= 1 else {
            return false
        }

        if left.count == right.count {
            return zip(left, right)
                .filter { $0.0 != $0.1 }
                .count <= 1
        }

        let shorter = left.count < right.count ? left : right
        let longer = left.count < right.count ? right : left
        var shortIndex = 0
        var longIndex = 0
        var skipped = false

        while shortIndex < shorter.count && longIndex < longer.count {
            if shorter[shortIndex] == longer[longIndex] {
                shortIndex += 1
                longIndex += 1
            } else if skipped {
                return false
            } else {
                skipped = true
                longIndex += 1
            }
        }
        return true
    }

    private func makeEvidence(
        input: MedicineRecognitionInput,
        normalizedName: NormalizedMedicineName,
        medicines: [Medicine]
    ) -> MedicineResolutionEvidence {
        MedicineResolutionEvidence(
            recognizedTexts: input.recognizedTexts,
            normalizedText: normalizedName.normalizedText,
            normalizedQuery: normalizedName.normalizedQuery,
            languageCode: input.languageCode,
            rawConfidence: input.rawConfidence,
            dosageForms: normalizedName.dosageForms,
            removedSpecifications:
                normalizedName.removedSpecifications,
            discardedNoise: normalizedName.discardedNoise,
            matcherVersion: configuration.matcherVersion,
            sourceDataVersions: Array(
                Set(medicines.map(\.dataVersion))
            )
            .sorted()
        )
    }

    private static func candidateOrder(
        _ lhs: MedicineCandidate,
        _ rhs: MedicineCandidate
    ) -> Bool {
        if lhs.matchScore != rhs.matchScore {
            return lhs.matchScore > rhs.matchScore
        }
        if lhs.medicine.canonicalName != rhs.medicine.canonicalName {
            return lhs.medicine.canonicalName
                < rhs.medicine.canonicalName
        }
        return lhs.medicine.id < rhs.medicine.id
    }

    private static func nameMatchOrder(
        _ lhs: NameMatch,
        _ rhs: NameMatch
    ) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        return (lhs.matchedAlias ?? "") < (rhs.matchedAlias ?? "")
    }

    private static func stableReasons(
        _ reasons: [MedicineMatchReason]
    ) -> [MedicineMatchReason] {
        let order = Dictionary(
            uniqueKeysWithValues: MedicineMatchReason.allCases
                .enumerated()
                .map { ($0.element, $0.offset) }
        )
        return Array(Set(reasons)).sorted {
            order[$0, default: .max] < order[$1, default: .max]
        }
    }
}

/// Compatibility alias for callers that adopted the initial draft name.
public typealias Resolver = MedicineResolver

private struct NameMatch {
    let score: Double
    let reasons: [MedicineMatchReason]
    let matchedAlias: String?
}
