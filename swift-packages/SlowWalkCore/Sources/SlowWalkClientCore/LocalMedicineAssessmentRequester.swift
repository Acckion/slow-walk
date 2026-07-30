import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
import SlowWalkMedicinePipeline

/// Device-local adapter from the existing client contract to MedicinePipeline.
///
/// It performs no HTTP request and retains at most one pending confirmation
/// context. Starting another assessment invalidates the previous context.
public actor LocalMedicineAssessmentRequester:
    MedicineAssessmentRequesting,
    MedicineCandidateConfirming
{
    private struct PendingConfirmation: Sendable {
        let request: MedicineAssessmentRequestDTO
        let context: MedicineConfirmationContext
    }

    private let pipeline: MedicinePipeline
    private var pendingConfirmation: PendingConfirmation?

    public init(pipeline: MedicinePipeline = MedicinePipeline()) {
        self.pipeline = pipeline
    }

    public init(clock: any Clock) {
        pipeline = MedicinePipeline(dateProvider: clock)
    }

    public func assess(
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO {
        try Task.checkCancellation()
        pendingConfirmation = nil
        try validateVersion(request)

        let records = try request.recentRecords.map { try $0.domainModel() }
        let result = try await pipeline.assess(
            input: request.input,
            userProfile: request.userProfile.domainModel,
            recentRecords: records
        )
        try Task.checkCancellation()

        if let context = result.confirmationContext {
            pendingConfirmation = PendingConfirmation(
                request: request,
                context: context
            )
        }
        return makeResponse(from: result, request: request)
    }

    public func confirmMedicine(
        command: MedicineCandidateConfirmationCommand
    ) async throws -> MedicineAssessmentResponseDTO {
        try Task.checkCancellation()
        guard let pendingConfirmation,
            pendingConfirmation.request.requestID
                == command.originalRequestID
        else {
            throw LocalMedicineConfirmationError.noPendingAssessment
        }
        guard
            pendingConfirmation.context.candidates.contains(
                where: { $0.medicine.id == command.candidateID }
            )
        else {
            throw LocalMedicineConfirmationError.candidateNotOffered
        }

        let request = pendingConfirmation.request
        let records = try request.recentRecords.map { try $0.domainModel() }
        let result = try await pipeline.assessConfirmedCandidate(
            candidateID: command.candidateID,
            context: pendingConfirmation.context,
            userProfile: request.userProfile.domainModel,
            recentRecords: records
        )
        try Task.checkCancellation()

        self.pendingConfirmation = nil
        return makeResponse(from: result, request: request)
    }

    private func validateVersion(
        _ request: MedicineAssessmentRequestDTO
    ) throws {
        guard
            SlowWalkAPI.supports(
                bodyVersion: request.apiVersion,
                for: .medicineAssess
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
    }

    private func makeResponse(
        from result: MedicinePipelineAssessmentResult,
        request: MedicineAssessmentRequestDTO
    ) -> MedicineAssessmentResponseDTO {
        MedicineAssessmentResponseDTO(
            requestID: request.requestID,
            resolution: result.resolution,
            assessment: result.assessment,
            actionCard: result.actionCard,
            cacheHit: result.cacheHit,
            resolutionCacheStatus: result.cacheStatus,
            knowledgeCacheStatus: result.knowledgeResult?.cacheStatus,
            sourceDataVersion: result.sourceDataVersion,
            generatedAt: result.generatedAt,
            apiVersion: request.apiVersion,
            healthContextValidation: HealthContextValidationDTO(
                result.healthContextValidation
            ),
            medicineKnowledge: result.knowledgeResult
        )
    }
}

public enum LocalMedicineConfirmationError:
    Error,
    Sendable,
    Equatable
{
    case noPendingAssessment
    case candidateNotOffered
}
