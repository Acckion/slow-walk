import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain

/// Semantic validation shared by the medicine resolution and assessment routes.
///
/// Codable decoding remains responsible for structural validation. These checks
/// reject values that are structurally valid JSON but unsafe or meaningless for
/// the deterministic pipeline.
public struct MedicinePipelineRequestValidator: Sendable {
    public init() {}

    public func validate(
        _ request: MedicineResolutionRequestDTO
    ) -> [APIErrorDetailDTO] {
        validateRecognitionConfidence(request.input)
    }

    public func validate(
        _ request: MedicineAssessmentRequestDTO
    ) -> [APIErrorDetailDTO] {
        validateRecognitionConfidence(request.input)
    }

    private func validateRecognitionConfidence(
        _ input: MedicineRecognitionInput
    ) -> [APIErrorDetailDTO] {
        var details = [APIErrorDetailDTO]()

        if let confidence = input.rawConfidence,
            !confidence.isFinite || !(0 ... 1).contains(confidence)
        {
            details.append(
                APIErrorDetailDTO(
                    field: "input.rawConfidence",
                    code: "out_of_range",
                    message: "Recognition confidence must be between 0 and 1."
                )
            )
        }

        return details
    }
}
