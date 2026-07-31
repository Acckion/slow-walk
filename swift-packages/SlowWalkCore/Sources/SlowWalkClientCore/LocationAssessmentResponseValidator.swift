import SlowWalkAPIContracts

/// Structural checks applied before a location response becomes view state.
public struct LocationAssessmentResponseValidator: Sendable {
    public init() {}

    public func validate(
        _ response: LocationAssessmentResponseDTO,
        for request: LocationAssessmentRequestDTO
    ) throws {
        guard response.requestID == request.requestID else {
            throw LocationAssessmentResponseValidationError.requestIDMismatch
        }
        guard response.apiVersion == request.apiVersion else {
            throw LocationAssessmentResponseValidationError.apiVersionMismatch
        }
        guard response.generatedAt == response.assessment.assessedAt,
            response.generatedAt == response.actionCard.generatedAt
        else {
            throw LocationAssessmentResponseValidationError.generatedAtMismatch
        }
        guard response.assessment.level == response.actionCard.riskLevel else {
            throw LocationAssessmentResponseValidationError.riskLevelMismatch
        }
        guard response.warnings == response.actionCard.warnings else {
            throw LocationAssessmentResponseValidationError.warningsMismatch
        }
    }
}

public enum LocationAssessmentResponseValidationError:
    Error,
    Sendable,
    Equatable
{
    case requestIDMismatch
    case apiVersionMismatch
    case generatedAtMismatch
    case riskLevelMismatch
    case warningsMismatch
}
