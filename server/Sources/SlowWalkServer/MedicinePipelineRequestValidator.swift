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

    public func validate(
        _ request: MedicineKnowledgeSearchRequestDTO
    ) -> [APIErrorDetailDTO] {
        let query = request.normalizedQuery
        let trimmed = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            return [
                APIErrorDetailDTO(
                    field: "normalizedQuery",
                    code: "required",
                    message:
                        "A normalized medicine query is required."
                ),
            ]
        }
        guard trimmed.count <= 256 else {
            return [
                APIErrorDetailDTO(
                    field: "normalizedQuery",
                    code: "too_long",
                    message:
                        "The normalized medicine query must not exceed 256 characters."
                ),
            ]
        }
        guard trimmed == trimmed.lowercased(),
            !trimmed.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0)
            })
        else {
            return [
                APIErrorDetailDTO(
                    field: "normalizedQuery",
                    code: "not_normalized",
                    message:
                        "The query must be trimmed, lowercase, and free of control characters."
                ),
            ]
        }
        return []
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
