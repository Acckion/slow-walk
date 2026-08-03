import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
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
    private let validator: LocationAssessmentContractValidator
    private let clock: any Clock

    public init(
        assessor: any LocationRiskAssessing,
        actionCardFactory: LocationActionCardFactory = .init()
    ) {
        self.init(
            assessor: assessor,
            clock: LocalLocationAssessmentClock(),
            actionCardFactory: actionCardFactory
        )
    }

    public init(
        assessor: any LocationRiskAssessing,
        clock: any Clock,
        actionCardFactory: LocationActionCardFactory = .init(),
        validator: LocationAssessmentContractValidator = .init()
    ) {
        self.assessor = assessor
        self.clock = clock
        self.actionCardFactory = actionCardFactory
        self.validator = validator
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

        let fieldDetails = validator.validateFields(request)
        guard fieldDetails.isEmpty else {
            throw ClientAPIError(
                error: APIErrorDTO(
                    code: .validationError,
                    message: "One or more destination fields are invalid.",
                    requestID: request.requestID,
                    details: fieldDetails
                )
            )
        }
        if let failure = validator.dataQualityFailure(
            for: request.recentSamples,
            relativeTo: clock.now()
        ) {
            throw ClientAPIError(
                error: APIErrorDTO(
                    code: failure.code,
                    message: failure.message,
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

private struct LocalLocationAssessmentClock: Clock {
    func now() -> Date {
        Date()
    }
}
