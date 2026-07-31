import SlowWalkMedicineKnowledge
import SlowWalkRiskEngine

/// Transport-neutral categories for errors that can escape MedicinePipeline.
///
/// Adapters map these categories to their own error envelope without importing
/// server code or exposing health-context details to presentation state.
public enum MedicinePipelineFailureKind: Sendable, Equatable {
    case invalidUserProfile
    case unsupportedProfileSchema
    case invalidMedicationRecord
    case futureMedicationRecord
    case invalidBodyMetrics
    case knowledgeSourceUnavailable
    case knowledgeSourceTimeout
    case invalidSourceResponse
    case sourceVersionUnsupported
    case medicineNotFound
    case sourceConflict
    case offlineCacheUnavailable
    case malformedRequest
    case internalInvariant
}

public enum MedicinePipelineFailureClassifier {
    public static func classify(
        _ error: any Error
    ) -> MedicinePipelineFailureKind? {
        if let buildError = error as? MedicationRiskContextBuildError {
            switch buildError {
            case .missingUserProfile, .invalidUserProfile:
                return .invalidUserProfile
            case .unsupportedProfileSchema:
                return .unsupportedProfileSchema
            case .invalidMedicationRecord:
                return .invalidMedicationRecord
            case .futureMedicationRecord:
                return .futureMedicationRecord
            case .invalidBodyMetrics:
                return .invalidBodyMetrics
            case .unresolvedMedicine, .medicineResolutionMismatch:
                return .internalInvariant
            }
        }

        if let knowledgeError = error as? MedicineKnowledgeError {
            switch knowledgeError {
            case .knowledgeSourceUnavailable:
                return .knowledgeSourceUnavailable
            case .requestCancelled:
                return nil
            case .knowledgeSourceTimeout:
                return .knowledgeSourceTimeout
            case .invalidSourceResponse:
                return .invalidSourceResponse
            case .sourceVersionUnsupported:
                return .sourceVersionUnsupported
            case .medicineNotFound:
                return .medicineNotFound
            case .sourceConflict:
                return .sourceConflict
            case .offlineCacheUnavailable:
                return .offlineCacheUnavailable
            case .malformedRequest:
                return .malformedRequest
            }
        }

        return nil
    }
}
