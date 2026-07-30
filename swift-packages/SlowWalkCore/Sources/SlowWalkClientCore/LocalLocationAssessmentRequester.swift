import Foundation
import SlowWalkAPIContracts
import SlowWalkLocationRisk

/// Device-local adapter from the client contract to LocationRiskEngine.
///
/// It accepts already bounded samples from `LocationAssessmentCoordinator` and
/// performs no HTTP request. Platform permission and sample collection remain
/// the responsibility of an injected `LocationSampleProviding` adapter.
public struct LocalLocationAssessmentRequester:
    LocationAssessmentRequesting,
    Sendable
{
    private let assessor: any LocationRiskAssessing
    private let actionCardFactory: LocationActionCardFactory

    public init(
        assessor: any LocationRiskAssessing,
        actionCardFactory: LocationActionCardFactory = .init()
    ) {
        self.assessor = assessor
        self.actionCardFactory = actionCardFactory
    }

    public func assess(
        request: LocationAssessmentRequestDTO
    ) async throws -> LocationAssessmentResponseDTO {
        try Task.checkCancellation()
        guard
            SlowWalkAPI.supports(
                bodyVersion: request.apiVersion,
                for: .locationAssess
            )
        else {
            throw ClientAPIError(
                error: APIErrorDTO(
                    code: .unsupportedAPIVersion,
                    message: "The requested API version is not supported.",
                    requestID: request.requestID,
                    details: nil
                )
            )
        }

        let assessment = try assessor.assess(
            destination: request.destination,
            recentSamples: request.recentSamples
        )
        try Task.checkCancellation()
        let card = actionCardFactory.makeCard(from: assessment)
        return LocationAssessmentResponseDTO(
            requestID: request.requestID,
            assessment: assessment,
            actionCard: card,
            warnings: card.warnings,
            generatedAt: assessment.assessedAt,
            apiVersion: request.apiVersion
        )
    }
}
