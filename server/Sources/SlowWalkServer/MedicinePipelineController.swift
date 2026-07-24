import Foundation
import Hummingbird
import SlowWalkAPIContracts
import SlowWalkDataInterfaces
import SlowWalkDomain
import SlowWalkMedicinePipeline
import SlowWalkRiskEngine

/// HTTP boundary for deterministic medicine resolution and assessment.
///
/// Recognition and risk decisions stay in `SlowWalkMedicinePipeline`. This
/// controller is responsible only for transport validation, stable HTTP
/// mappings, and API DTO construction.
public struct MedicinePipelineController: Sendable {
    private let pipeline: MedicinePipeline
    private let validator: MedicinePipelineRequestValidator
    private let uuidProvider: any UUIDProviding

    public init(
        pipeline: MedicinePipeline,
        validator: MedicinePipelineRequestValidator = .init(),
        uuidProvider: any UUIDProviding = SystemUUIDProvider()
    ) {
        self.pipeline = pipeline
        self.validator = validator
        self.uuidProvider = uuidProvider
    }

    public func resolve(
        request: Request,
        context: SlowWalkRequestContext
    ) async throws -> Response {
        let fallbackRequestID = uuidProvider.makeUUID()
        let decoded: DecodedMedicineRequest<MedicineResolutionRequestDTO> =
            try await decodeRequest(
                request,
                context: context,
                fallbackRequestID: fallbackRequestID,
                operation: "medicine_resolution"
            )

        let input: MedicineResolutionRequestDTO
        switch decoded {
        case .value(let value):
            input = value
        case .rejection(let response):
            return response
        }

        if let rejection = try validateTransport(
            apiVersion: input.apiVersion,
            requestID: input.requestID,
            details: validator.validate(input),
            request: request,
            context: context,
            operation: "medicine_resolution"
        ) {
            return rejection
        }

        do {
            let result = try await pipeline.resolve(input: input.input)
            switch result.resolution.status {
            case .resolved:
                let output = MedicineResolutionResponseDTO(
                    requestID: input.requestID,
                    resolution: result.resolution,
                    cacheHit: result.cacheHit,
                    cacheStatus: result.cacheStatus,
                    sourceDataVersion: result.sourceDataVersion,
                    generatedAt: result.generatedAt,
                    apiVersion: SlowWalkAPI.version
                )
                return try jsonResponse(
                    output,
                    status: .ok,
                    request: request,
                    context: context
                )

            case .ambiguous:
                return try resolutionRejection(
                    code: "medicine_ambiguous",
                    message: "More than one medicine matched the recognized text.",
                    status: .conflict,
                    requestID: input.requestID,
                    request: request,
                    context: context
                )

            case .notFound:
                return try resolutionRejection(
                    code: "medicine_not_found",
                    message: "No verified medicine matched the recognized text.",
                    status: .notFound,
                    requestID: input.requestID,
                    request: request,
                    context: context
                )

            case .recognitionFailed:
                return try resolutionRejection(
                    code: "medicine_recognition_failed",
                    message: "The medicine text could not be recognized reliably.",
                    status: .unprocessableContent,
                    requestID: input.requestID,
                    request: request,
                    context: context
                )

            case .insufficientEvidence:
                return try resolutionRejection(
                    code: "medicine_insufficient_evidence",
                    message: "The available recognition evidence is insufficient.",
                    status: .unprocessableContent,
                    requestID: input.requestID,
                    request: request,
                    context: context
                )
            }
        } catch {
            return try internalErrorResponse(
                operation: "medicine_resolution",
                requestID: input.requestID,
                error: error,
                request: request,
                context: context
            )
        }
    }

    public func assess(
        request: Request,
        context: SlowWalkRequestContext
    ) async throws -> Response {
        let fallbackRequestID = uuidProvider.makeUUID()
        let decoded: DecodedMedicineRequest<MedicineAssessmentRequestDTO> =
            try await decodeRequest(
                request,
                context: context,
                fallbackRequestID: fallbackRequestID,
                operation: "medicine_assessment"
            )

        let input: MedicineAssessmentRequestDTO
        switch decoded {
        case .value(let value):
            input = value
        case .rejection(let response):
            return response
        }

        if let rejection = try validateTransport(
            apiVersion: input.apiVersion,
            requestID: input.requestID,
            details: validator.validate(input),
            request: request,
            context: context,
            operation: "medicine_assessment"
        ) {
            return rejection
        }

        do {
            let result = try await pipeline.assess(
                input: input.input,
                userProfile: input.userProfile,
                recentRecords: input.recentRecords
            )
            let output = MedicineAssessmentResponseDTO(
                requestID: input.requestID,
                resolution: result.resolution,
                assessment: result.assessment,
                actionCard: result.actionCard,
                cacheHit: result.cacheHit,
                cacheStatus: result.cacheStatus,
                sourceDataVersion: result.sourceDataVersion,
                generatedAt: result.generatedAt,
                apiVersion: SlowWalkAPI.version,
                healthContextValidation: HealthContextValidationDTO(
                    result.healthContextValidation
                )
            )

            // Every valid recognition state, including unresolved states, is a
            // successful assessment transport response. The pipeline supplies
            // the conservative ActionCard for those states.
            return try jsonResponse(
                output,
                status: .ok,
                request: request,
                context: context
            )
        } catch let buildError as MedicationRiskContextBuildError {
            return try healthContextRejection(
                buildError,
                requestID: input.requestID,
                request: request,
                context: context
            )
        } catch {
            return try internalErrorResponse(
                operation: "medicine_assessment",
                requestID: input.requestID,
                error: error,
                request: request,
                context: context
            )
        }
    }

    private func decodeRequest<Value: Decodable & Sendable>(
        _ request: Request,
        context: SlowWalkRequestContext,
        fallbackRequestID: UUID,
        operation: String
    ) async throws -> DecodedMedicineRequest<Value> {
        guard hasJSONContentType(request) else {
            return .rejection(
                try rejectionResponse(
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
                    operation: operation,
                    request: request,
                    context: context
                )
            )
        }

        do {
            return .value(
                try await context.requestDecoder.decode(
                    Value.self,
                    from: request,
                    context: context
                )
            )
        } catch let decodingError as DecodingError {
            switch RequestDecodingFailure(error: decodingError) {
            case .malformedJSON:
                let errorCode = operation == "medicine_assessment"
                    ? "MALFORMED_REQUEST"
                    : "invalid_json"
                return .rejection(
                    try rejectionResponse(
                        code: errorCode,
                        message: "The request body is not valid JSON.",
                        requestID: fallbackRequestID,
                        details: nil,
                        status: .badRequest,
                        operation: operation,
                        request: request,
                        context: context
                    )
                )

            case .validation(let detail):
                let errorCode = decodingErrorCode(
                    operation: operation,
                    detail: detail
                )
                return .rejection(
                    try rejectionResponse(
                        code: errorCode,
                        message: "One or more request fields are invalid.",
                        requestID: fallbackRequestID,
                        details: [detail],
                        status: .unprocessableContent,
                        operation: operation,
                        request: request,
                        context: context
                    )
                )
            }
        } catch {
            context.logger.warning(
                "\(operation)_decode_failed",
                metadata: [
                    "slowwalk.api_request_id": .string(
                        fallbackRequestID.uuidString
                    ),
                    "slowwalk.error_type": .string(
                        String(describing: type(of: error))
                    ),
                ]
            )
            return .rejection(
                try rejectionResponse(
                    code: "invalid_json",
                    message: "The request body could not be decoded.",
                    requestID: fallbackRequestID,
                    details: nil,
                    status: .badRequest,
                    operation: operation,
                    request: request,
                    context: context
                )
            )
        }
    }

    private func validateTransport(
        apiVersion: String,
        requestID: UUID,
        details: [APIErrorDetailDTO],
        request: Request,
        context: SlowWalkRequestContext,
        operation: String
    ) throws -> Response? {
        guard apiVersion == SlowWalkAPI.version else {
            let errorCode = operation == "medicine_assessment"
                ? "UNSUPPORTED_API_VERSION"
                : "unsupported_api_version"
            return try rejectionResponse(
                code: errorCode,
                message: "The requested API version is not supported.",
                requestID: requestID,
                details: [
                    APIErrorDetailDTO(
                        field: "apiVersion",
                        code: "unsupported",
                        message: "Supported API version: \(SlowWalkAPI.version)."
                    )
                ],
                status: .badRequest,
                operation: operation,
                request: request,
                context: context
            )
        }

        guard details.isEmpty else {
            return try rejectionResponse(
                code: "validation_error",
                message: "One or more request fields are invalid.",
                requestID: requestID,
                details: details,
                status: .unprocessableContent,
                operation: operation,
                request: request,
                context: context
            )
        }
        return nil
    }

    private func decodingErrorCode(
        operation: String,
        detail: APIErrorDetailDTO
    ) -> String {
        guard operation == "medicine_assessment" else {
            return "validation_error"
        }
        guard let field = detail.field else {
            return "MALFORMED_REQUEST"
        }
        if field == "userProfile"
            || field.hasPrefix("userProfile.") {
            if field == "userProfile.bodyMetrics"
                || field.hasPrefix("userProfile.bodyMetrics.") {
                return "INVALID_BODY_METRICS"
            }
            return "INVALID_USER_PROFILE"
        }
        if field == "recentRecords"
            || field.hasPrefix("recentRecords.") {
            return "INVALID_MEDICATION_RECORD"
        }
        return "MALFORMED_REQUEST"
    }

    private func healthContextRejection(
        _ error: MedicationRiskContextBuildError,
        requestID: UUID,
        request: Request,
        context: SlowWalkRequestContext
    ) throws -> Response {
        let code: String
        let message: String
        let issues: [HealthContextValidationIssue]
        switch error {
        case .missingUserProfile:
            code = "INVALID_USER_PROFILE"
            message = "The user health profile is required."
            issues = []
        case .invalidUserProfile(let values):
            code = "INVALID_USER_PROFILE"
            message = "The user health profile is invalid."
            issues = values
        case .unsupportedProfileSchema(let values):
            code = "UNSUPPORTED_PROFILE_SCHEMA"
            message = "The user health profile schema is not supported."
            issues = values
        case .invalidMedicationRecord(let values):
            code = "INVALID_MEDICATION_RECORD"
            message = "Medication history contains an invalid record."
            issues = values
        case .futureMedicationRecord(let values):
            code = "FUTURE_MEDICATION_RECORD"
            message = "Medication history contains a future record."
            issues = values
        case .invalidBodyMetrics(let values):
            code = "INVALID_BODY_METRICS"
            message = "Body metrics failed data-quality validation."
            issues = values
        case .unresolvedMedicine, .medicineResolutionMismatch:
            return try internalErrorResponse(
                operation: "medicine_assessment",
                requestID: requestID,
                error: error,
                request: request,
                context: context
            )
        }
        return try rejectionResponse(
            code: code,
            message: message,
            requestID: requestID,
            details: issues.map {
                APIErrorDetailDTO(
                    field: $0.field,
                    code: $0.code,
                    message: $0.message
                )
            },
            status: .unprocessableContent,
            operation: "medicine_assessment",
            request: request,
            context: context
        )
    }

    private func resolutionRejection(
        code: String,
        message: String,
        status: HTTPResponse.Status,
        requestID: UUID,
        request: Request,
        context: SlowWalkRequestContext
    ) throws -> Response {
        try rejectionResponse(
            code: code,
            message: message,
            requestID: requestID,
            details: nil,
            status: status,
            operation: "medicine_resolution",
            request: request,
            context: context
        )
    }

    private func internalErrorResponse(
        operation: String,
        requestID: UUID,
        error: any Error,
        request: Request,
        context: SlowWalkRequestContext
    ) throws -> Response {
        context.logger.error(
            "\(operation)_failed",
            metadata: [
                "slowwalk.api_request_id": .string(requestID.uuidString),
                "slowwalk.error_type": .string(
                    String(describing: type(of: error))
                ),
            ]
        )
        return try rejectionResponse(
            code: "internal_error",
            message: "The server could not complete the medicine request.",
            requestID: requestID,
            details: nil,
            status: .internalServerError,
            operation: operation,
            request: request,
            context: context
        )
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
        operation: String,
        request: Request,
        context: SlowWalkRequestContext
    ) throws -> Response {
        context.logger.warning(
            "\(operation)_rejected",
            metadata: [
                "slowwalk.api_request_id": .string(requestID.uuidString),
                "slowwalk.error_code": .string(code),
                "slowwalk.http_status": .string(String(status.code)),
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

private enum DecodedMedicineRequest<Value: Sendable>: Sendable {
    case value(Value)
    case rejection(Response)
}
