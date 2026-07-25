import Foundation
import Hummingbird
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkLocationRisk

/// HTTP boundary for deterministic location-risk assessment.
///
/// Location rules remain in `SlowWalkLocationRisk`; this controller only
/// performs transport validation and stable error mapping.
public struct LocationAssessmentController: Sendable {
    private let assessor: any LocationRiskAssessing
    private let actionCardFactory: LocationActionCardFactory
    private let validator: LocationAssessmentRequestValidator
    private let dateProvider: any DateProviding
    private let uuidProvider: any UUIDProviding

    public init(
        assessor: any LocationRiskAssessing,
        actionCardFactory: LocationActionCardFactory = .init(),
        validator: LocationAssessmentRequestValidator = .init(),
        dateProvider: any DateProviding =
            SystemDateProvider(),
        uuidProvider: any UUIDProviding =
            SystemUUIDProvider()
    ) {
        self.assessor = assessor
        self.actionCardFactory = actionCardFactory
        self.validator = validator
        self.dateProvider = dateProvider
        self.uuidProvider = uuidProvider
    }

    public func handle(
        request: Request,
        context: SlowWalkRequestContext
    ) async throws -> Response {
        let fallbackRequestID = uuidProvider.makeUUID()
        guard hasJSONContentType(request) else {
            return try rejectionResponse(
                code: .unsupportedMediaType,
                message: "Content-Type must be application/json.",
                requestID: fallbackRequestID,
                details: nil,
                status: .badRequest,
                request: request,
                context: context
            )
        }

        let input: LocationAssessmentRequestDTO
        do {
            input = try await context.requestDecoder.decode(
                LocationAssessmentRequestDTO.self,
                from: request,
                context: context
            )
        } catch let decodingError as DecodingError {
            let details: [APIErrorDetailDTO]?
            switch RequestDecodingFailure(
                error: decodingError
            ) {
            case .malformedJSON:
                details = nil
            case .validation(let detail):
                details = [detail]
            }
            return try rejectionResponse(
                code: .malformedRequest,
                message:
                    "The location assessment request is not valid JSON.",
                requestID: fallbackRequestID,
                details: details,
                status: .badRequest,
                request: request,
                context: context
            )
        } catch {
            return try rejectionResponse(
                code: .malformedRequest,
                message:
                    "The location assessment request could not be decoded.",
                requestID: fallbackRequestID,
                details: nil,
                status: .badRequest,
                request: request,
                context: context
            )
        }

        guard SlowWalkAPI.supports(
            bodyVersion: input.apiVersion,
            for: .locationAssess
        ) else {
            return try rejectionResponse(
                code: .unsupportedAPIVersion,
                message:
                    "The requested API version is not supported.",
                requestID: input.requestID,
                details: [
                    APIErrorDetailDTO(
                        field: "apiVersion",
                        code: "unsupported",
                        message:
                            "Supported API version: \(SlowWalkAPI.version)."
                    ),
                ],
                status: .badRequest,
                request: request,
                context: context
            )
        }

        let fieldDetails = validator.validateFields(input)
        guard fieldDetails.isEmpty else {
            return try rejectionResponse(
                code: .validationError,
                message:
                    "One or more destination fields are invalid.",
                requestID: input.requestID,
                details: fieldDetails,
                status: .unprocessableContent,
                request: request,
                context: context
            )
        }

        if let failure = validator.dataQualityFailure(
            for: input.recentSamples,
            relativeTo: dateProvider.now()
        ) {
            return try rejectionResponse(
                code: failure.code,
                message: failure.message,
                requestID: input.requestID,
                details: nil,
                status: .unprocessableContent,
                request: request,
                context: context
            )
        }

        do {
            let assessment = try assessor.assess(
                destination: input.destination,
                recentSamples: input.recentSamples
            )
            let card = actionCardFactory.makeCard(
                from: assessment
            )
            let output = LocationAssessmentResponseDTO(
                requestID: input.requestID,
                assessment: assessment,
                actionCard: card,
                warnings: card.warnings,
                generatedAt: assessment.assessedAt,
                apiVersion: SlowWalkAPI.version
            )
            context.logger.info(
                "location_assessment_completed",
                metadata: [
                    "slowwalk.api_request_id": .string(
                        input.requestID.uuidString
                    ),
                    "slowwalk.location_risk_level": .string(
                        assessment.level.rawValue
                    ),
                ]
            )
            return try jsonResponse(
                output,
                status: .ok,
                request: request,
                context: context
            )
        } catch {
            context.logger.warning(
                "location_assessment_rejected",
                metadata: [
                    "slowwalk.api_request_id": .string(
                        input.requestID.uuidString
                    ),
                    "slowwalk.error_type": .string(
                        String(describing: type(of: error))
                    ),
                ]
            )
            return try rejectionResponse(
                code: .validationError,
                message:
                    "The destination could not be assessed.",
                requestID: input.requestID,
                details: nil,
                status: .unprocessableContent,
                request: request,
                context: context
            )
        }
    }

    private func hasJSONContentType(
        _ request: Request
    ) -> Bool {
        guard let header = request.headers[.contentType],
              let mediaType = MediaType(from: header)
        else {
            return false
        }
        return mediaType.isType(.applicationJson)
    }

    private func rejectionResponse(
        code: APIErrorCode,
        message: String,
        requestID: UUID,
        details: [APIErrorDetailDTO]?,
        status: HTTPResponse.Status,
        request: Request,
        context: SlowWalkRequestContext
    ) throws -> Response {
        context.logger.warning(
            "location_assessment_rejected",
            metadata: [
                "slowwalk.api_request_id": .string(
                    requestID.uuidString
                ),
                "slowwalk.error_code": .string(
                    code.rawValue
                ),
                "slowwalk.http_status": .string(
                    String(status.code)
                ),
            ]
        )
        return try jsonResponse(
            APIErrorDTO(
                code: code,
                message: message,
                requestID: requestID,
                details: details
            ),
            status: status,
            request: request,
            context: context
        )
    }

    private func jsonResponse<Value: Encodable>(
        _ value: Value,
        status: HTTPResponse.Status,
        request: Request,
        context: SlowWalkRequestContext
    ) throws -> Response {
        var response = try context.responseEncoder.encode(
            value,
            from: request,
            context: context
        )
        response.status = status
        return response
    }
}
