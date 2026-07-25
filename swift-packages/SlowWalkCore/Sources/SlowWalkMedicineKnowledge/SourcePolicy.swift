import Foundation

public struct SourcePolicy:
    Sendable,
    Equatable
{
    public static let demo = SourcePolicy(
        allowedSourceIdentifiers: [
            MockAuthoritativeMedicineSource.identifier,
            MockSecondaryMedicineSource.identifier,
        ],
        maximumSourceAge: 30 * 24 * 60 * 60,
        maximumFutureSkew: 5 * 60,
        minimumCompleteness: 0.5,
        conflictPenalty: 0.25
    )

    public let allowedSourceIdentifiers: Set<String>
    public let maximumSourceAge: TimeInterval
    public let maximumFutureSkew: TimeInterval
    public let minimumCompleteness: Double
    public let conflictPenalty: Double

    public init(
        allowedSourceIdentifiers: Set<String>,
        maximumSourceAge: TimeInterval,
        maximumFutureSkew: TimeInterval = 5 * 60,
        minimumCompleteness: Double,
        conflictPenalty: Double
    ) {
        self.allowedSourceIdentifiers = allowedSourceIdentifiers
        self.maximumSourceAge = maximumSourceAge
        self.maximumFutureSkew = maximumFutureSkew
        self.minimumCompleteness = minimumCompleteness
        self.conflictPenalty = conflictPenalty
    }

    public func orderedSources(
        _ sources: [any MedicineKnowledgeSource]
    ) throws -> [any MedicineKnowledgeSource] {
        var identifiers = Set<String>()
        for source in sources {
            guard allowedSourceIdentifiers.contains(
                source.identifier
            ) else {
                throw SourcePolicyError.sourceNotWhitelisted(
                    source.identifier
                )
            }
            guard identifiers.insert(source.identifier).inserted else {
                throw SourcePolicyError.duplicateSourceIdentifier(
                    source.identifier
                )
            }
            guard !source.supportedDataVersion
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            else {
                throw SourcePolicyError.emptySupportedDataVersion(
                    source.identifier
                )
            }
        }
        return sources.sorted {
            if $0.priority == $1.priority {
                if $0.isAuthoritative != $1.isAuthoritative {
                    return $0.isAuthoritative
                }
                return $0.identifier < $1.identifier
            }
            return $0.priority > $1.priority
        }
    }

    public func validate(
        response: MedicineKnowledgeSourceResponse,
        from source: any MedicineKnowledgeSource,
        now: Date
    ) throws -> [MedicineKnowledgeWarning] {
        guard allowedSourceIdentifiers.contains(source.identifier) else {
            throw SourcePolicyError.sourceNotWhitelisted(
                source.identifier
            )
        }
        guard response.sourceIdentifier == source.identifier else {
            throw SourcePolicyError.sourceIdentifierMismatch(
                expected: source.identifier,
                actual: response.sourceIdentifier
            )
        }
        guard response.sourceDocumentVersion
            == source.supportedDataVersion
        else {
            throw SourcePolicyError.unsupportedDataVersion(
                sourceIdentifier: source.identifier,
                version: response.sourceDocumentVersion
            )
        }
        if let metadataVersion =
            response.validationMetadata.dataVersion
        {
            guard metadataVersion
                == response.sourceDocumentVersion
            else {
                throw SourcePolicyError
                    .unsupportedDataVersion(
                        sourceIdentifier:
                            source.identifier,
                        version: metadataVersion
                    )
            }
        }
        guard response.validationStatus != .invalid else {
            throw SourcePolicyError.invalidValidationStatus(
                source.identifier
            )
        }
        try validateCompleteness(
            response.completeness,
            sourceIdentifier: source.identifier
        )
        guard response.fetchedAt
            <= now.addingTimeInterval(maximumFutureSkew)
        else {
            throw SourcePolicyError.futureFetchedAt(
                source.identifier
            )
        }
        guard !response.sourceReference.sourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
            !response.sourceReference.documentTitle
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            !response.sourceReference.versionOrDate
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        else {
            throw SourcePolicyError.missingSourceReference(
                source.identifier
            )
        }

        if response.validationStatus != .notModified {
            for record in response.records {
                try validate(
                    record: record,
                    response: response,
                    source: source,
                    now: now
                )
            }
        }

        var warnings = [MedicineKnowledgeWarning]()
        if now.timeIntervalSince(response.fetchedAt)
            > maximumSourceAge
        {
            warnings.append(
                MedicineKnowledgeWarning(
                    code: .sourceStale,
                    message:
                        "The source data is older than the configured data-quality window.",
                    sourceIdentifiers: [source.identifier]
                )
            )
        }
        if response.completeness < minimumCompleteness {
            warnings.append(
                MedicineKnowledgeWarning(
                    code: .invalidSourceResponse,
                    message:
                        "The source response is below the configured completeness threshold.",
                    sourceIdentifiers: [source.identifier]
                )
            )
        }
        return warnings
    }

    private func validate(
        record: MedicineKnowledgeRecord,
        response: MedicineKnowledgeSourceResponse,
        source: any MedicineKnowledgeSource,
        now: Date
    ) throws {
        guard record.sourceIdentifier == source.identifier else {
            throw SourcePolicyError.recordSourceIdentifierMismatch(
                expected: source.identifier,
                actual: record.sourceIdentifier
            )
        }
        guard record.sourceDocumentVersion
            == response.sourceDocumentVersion
        else {
            throw SourcePolicyError.recordVersionMismatch(
                source.identifier
            )
        }
        guard record.validationStatus != .invalid,
            record.validationStatus != .notModified
        else {
            throw SourcePolicyError.invalidRecordValidationStatus(
                source.identifier
            )
        }
        try validateCompleteness(
            record.completeness,
            sourceIdentifier: source.identifier
        )
        guard !record.canonicalMedicineIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
            !record.canonicalName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            !record.activeIngredientIDs.isEmpty
        else {
            throw SourcePolicyError.invalidMedicineRecord(
                source.identifier
            )
        }
        guard record.fetchedAt
            <= now.addingTimeInterval(maximumFutureSkew)
        else {
            throw SourcePolicyError.futureFetchedAt(
                source.identifier
            )
        }
        guard !record.sourceReference.sourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty,
            !record.sourceReference.documentTitle
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
            !record.sourceReference.versionOrDate
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        else {
            throw SourcePolicyError.missingSourceReference(
                source.identifier
            )
        }
    }

    private func validateCompleteness(
        _ value: Double,
        sourceIdentifier: String
    ) throws {
        guard value.isFinite, (0 ... 1).contains(value) else {
            throw SourcePolicyError.invalidCompleteness(
                sourceIdentifier
            )
        }
    }
}

public enum SourcePolicyError:
    Error,
    Sendable,
    Equatable
{
    case sourceNotWhitelisted(String)
    case duplicateSourceIdentifier(String)
    case emptySupportedDataVersion(String)
    case sourceIdentifierMismatch(expected: String, actual: String)
    case unsupportedDataVersion(
        sourceIdentifier: String,
        version: String
    )
    case invalidValidationStatus(String)
    case invalidRecordValidationStatus(String)
    case invalidCompleteness(String)
    case futureFetchedAt(String)
    case missingSourceReference(String)
    case recordSourceIdentifierMismatch(
        expected: String,
        actual: String
    )
    case recordVersionMismatch(String)
    case invalidMedicineRecord(String)
}
