import Foundation
import Hummingbird
import SlowWalkAPIContracts
import SlowWalkDataInterfaces

/// HTTP boundary for risk assessment. Domain decisions remain in `MedicationRiskEngine`.
public struct RiskAssessmentController: Sendable {
    private let service: RiskAssessmentService
    private let validator: RiskAssessmentRequestValidator
    private let uuidProvider: any UUIDProviding

    public init(
        service: RiskAssessmentService,
        validator: RiskAssessmentRequestValidator = .init(),
        uuidProvider: any UUIDProviding = SystemUUIDProvider()
    ) {
        self.service = service
        self.validator = validator
        self.uuidProvider = uuidProvider
    }

    public func handle(
        request: Request,
        context: SlowWalkRequestContext
    ) async throws -> Response {
        let fallbackRequestID = uuidProvider.makeUUID()

        guard hasJSONContentType(request) else {
            return try rejectionResponse(
                code: "unsupported_media_type",
                message: "Content-Type must be application/json.",
                requestID: fallbackRequestID,
                details: [
                    APIErrorDetailDTO(
                        field: "Content-Type",
                        code: "required_header",
                        message: "Set Content-Type to application/json."
                    )
                ],
                status: .badRequest,
                request: request,
                context: context
            )
        }

        let input: RiskAssessmentRequestDTO
        do {
            input = try await context.requestDecoder.decode(
                RiskAssessmentRequestDTO.self,
                from: request,
                context: context
            )
        } catch let decodingError as DecodingError {
            switch RequestDecodingFailure(error: decodingError) {
            case .malformedJSON:
                return try rejectionResponse(
                    code: "invalid_json",
                    message: "The request body is not valid JSON.",
                    requestID: fallbackRequestID,
                    details: nil,
                    status: .badRequest,
                    request: request,
                    context: context
                )

            case .validation(let detail):
                return try rejectionResponse(
                    code: "validation_error",
                    message: "One or more request fields are invalid.",
                    requestID: fallbackRequestID,
                    details: [detail],
                    status: .unprocessableContent,
                    request: request,
                    context: context
                )
            }
        } catch {
            context.logger.warning(
                "risk_assessment_decode_failed",
                metadata: [
                    "slowwalk.api_request_id": .string(
                        fallbackRequestID.uuidString
                    ),
                    "slowwalk.error_type": .string(
                        String(describing: type(of: error))
                    ),
                ]
            )
            return try rejectionResponse(
                code: "invalid_json",
                message: "The request body could not be decoded.",
                requestID: fallbackRequestID,
                details: nil,
                status: .badRequest,
                request: request,
                context: context
            )
        }

        guard input.apiVersion == SlowWalkAPI.version else {
            return try rejectionResponse(
                code: "unsupported_api_version",
                message: "The requested API version is not supported.",
                requestID: input.requestID,
                details: [
                    APIErrorDetailDTO(
                        field: "apiVersion",
                        code: "unsupported",
                        message: "Supported API version: \(SlowWalkAPI.version)."
                    )
                ],
                status: .badRequest,
                request: request,
                context: context
            )
        }

        let validationDetails = validator.validate(input)
        guard validationDetails.isEmpty else {
            return try rejectionResponse(
                code: "validation_error",
                message: "One or more request fields are invalid.",
                requestID: input.requestID,
                details: validationDetails,
                status: .unprocessableContent,
                request: request,
                context: context
            )
        }

        let output = service.assess(request: input)
        context.logger.info(
            "risk_assessment_completed",
            metadata: [
                "slowwalk.api_request_id": .string(input.requestID.uuidString),
                "slowwalk.api_version": .string(output.apiVersion),
                "slowwalk.risk_level": .string(output.assessment.level.rawValue),
            ]
        )

        do {
            return try jsonResponse(
                output,
                status: .ok,
                request: request,
                context: context
            )
        } catch {
            context.logger.error(
                "risk_assessment_encode_failed",
                metadata: [
                    "slowwalk.api_request_id": .string(input.requestID.uuidString),
                    "slowwalk.error_type": .string(
                        String(describing: type(of: error))
                    ),
                ]
            )
            return try rejectionResponse(
                code: "internal_error",
                message: "The server could not complete the assessment.",
                requestID: input.requestID,
                details: nil,
                status: .internalServerError,
                request: request,
                context: context
            )
        }
    }

    private func hasJSONContentType(_ request: Request) -> Bool {
        guard
            let header = request.headers[.contentType],
            let mediaType = MediaType(from: header)
        else {
            return false
        }
        return mediaType.isType(.applicationJson)
    }

    private func rejectionResponse(
        code: String,
        message: String,
        requestID: UUID,
        details: [APIErrorDetailDTO]?,
        status: HTTPResponse.Status,
        request: Request,
        context: SlowWalkRequestContext
    ) throws -> Response {
        context.logger.warning(
            "risk_assessment_rejected",
            metadata: [
                "slowwalk.api_request_id": .string(requestID.uuidString),
                "slowwalk.error_code": .string(code),
                "slowwalk.http_status": .string(String(status.code)),
            ]
        )
        let error = APIErrorDTO(
            code: code,
            message: message,
            requestID: requestID,
            details: details
        )
        return try jsonResponse(
            error,
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
