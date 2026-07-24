import Foundation
import SlowWalkAPIContracts

public struct RiskAssessmentRequestValidator: Sendable {
    public init() {}

    public func validate(
        _ request: RiskAssessmentRequestDTO
    ) -> [APIErrorDetailDTO] {
        var details = [APIErrorDetailDTO]()

        if request.medicine.id.isBlank {
            details.append(
                requiredDetail(
                    field: "medicine.id",
                    message: "Medicine ID is required."
                )
            )
        }

        if request.medicine.canonicalName.isBlank {
            details.append(
                requiredDetail(
                    field: "medicine.canonicalName",
                    message: "Medicine canonical name is required."
                )
            )
        }

        if request.medicine.activeIngredientIDs.isEmpty
            || request.medicine.activeIngredientIDs.contains(where: \.isBlank) {
            details.append(
                requiredDetail(
                    field: "medicine.activeIngredientIDs",
                    message: "At least one non-empty active ingredient ID is required."
                )
            )
        }

        if !(1 ... 130).contains(request.userProfile.age) {
            details.append(
                APIErrorDetailDTO(
                    field: "userProfile.age",
                    code: "out_of_range",
                    message: "Age must be between 1 and 130."
                )
            )
        }

        if !request.scanEvent.confidence.isFinite
            || !(0 ... 1).contains(request.scanEvent.confidence) {
            details.append(
                APIErrorDetailDTO(
                    field: "scanEvent.confidence",
                    code: "out_of_range",
                    message: "Recognition confidence must be between 0 and 1."
                )
            )
        }

        return details
    }

    private func requiredDetail(
        field: String,
        message: String
    ) -> APIErrorDetailDTO {
        APIErrorDetailDTO(
            field: field,
            code: "required",
            message: message
        )
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
