import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain

/// Structural checks applied before a response can become presentation state.
public struct MedicineAssessmentResponseValidator: Sendable {
    public init() {}

    public func validate(
        _ response: MedicineAssessmentResponseDTO,
        for request: MedicineAssessmentRequestDTO
    ) throws {
        guard response.requestID == request.requestID else {
            throw MedicineAssessmentResponseValidationError.requestIDMismatch
        }
        guard response.apiVersion == request.apiVersion else {
            throw MedicineAssessmentResponseValidationError.apiVersionMismatch
        }
        guard !response.sourceDataVersion
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw MedicineAssessmentResponseValidationError
                .missingSourceDataVersion
        }
        guard response.generatedAt == response.actionCard.generatedAt else {
            throw MedicineAssessmentResponseValidationError
                .generatedAtMismatch
        }

        let candidateIDs = response.resolution.candidates.map {
            $0.medicine.id
        }
        guard Set(candidateIDs).count == candidateIDs.count else {
            throw MedicineAssessmentResponseValidationError
                .duplicateCandidateID
        }

        switch response.resolution.status {
        case .resolved:
            guard let selected = response.resolution.selectedMedicine,
                  candidateIDs.contains(selected.id)
            else {
                throw MedicineAssessmentResponseValidationError
                    .invalidResolution
            }
        case .ambiguous,
             .insufficientEvidence,
             .notFound,
             .recognitionFailed:
            guard response.resolution.selectedMedicine == nil,
                  response.assessment == nil
            else {
                throw MedicineAssessmentResponseValidationError
                    .invalidResolution
            }
        }

        if let assessment = response.assessment {
            guard response.resolution.status == .resolved,
                  assessment.level == response.actionCard.riskLevel
            else {
                throw MedicineAssessmentResponseValidationError
                    .assessmentMismatch
            }
        }

        if response.resolution.requiresUserConfirmation {
            guard response.actionCard.mustConfirmMedicine else {
                throw MedicineAssessmentResponseValidationError
                    .confirmationMismatch
            }
        }
    }
}

public enum MedicineAssessmentResponseValidationError:
    Error,
    Sendable,
    Equatable
{
    case requestIDMismatch
    case apiVersionMismatch
    case missingSourceDataVersion
    case generatedAtMismatch
    case duplicateCandidateID
    case invalidResolution
    case assessmentMismatch
    case confirmationMismatch
}
