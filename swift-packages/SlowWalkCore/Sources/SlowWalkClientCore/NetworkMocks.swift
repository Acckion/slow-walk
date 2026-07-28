import Foundation
import SlowWalkAPIContracts

public enum MockMedicineTextRecognizerBehavior:
    Sendable,
    Equatable
{
    case observations([RecognizedTextObservation])
    case failure(OCRRecognitionError)
    case cancellation
}

public struct MockMedicineTextRecognizer:
    MedicineTextRecognizing,
    Sendable
{
    public let behavior:
        MockMedicineTextRecognizerBehavior

    public init(
        behavior: MockMedicineTextRecognizerBehavior
    ) {
        self.behavior = behavior
    }

    public func recognizeText(
        in input: OCRImageInput
    ) async throws -> [RecognizedTextObservation] {
        try Task.checkCancellation()
        switch behavior {
        case let .observations(observations):
            return observations
        case let .failure(error):
            throw error
        case .cancellation:
            throw CancellationError()
        }
    }
}

public enum MockMedicineAssessmentBehavior:
    Sendable,
    Equatable
{
    case success(MedicineAssessmentResponseDTO)
    case ambiguousMedicine(
        MedicineAssessmentResponseDTO
    )
    case incompleteHealthProfile(requestID: UUID)
    case knowledgeSourceWarning(
        MedicineAssessmentResponseDTO
    )
    case redRisk(MedicineAssessmentResponseDTO)
    case malformedResponse
    case cancellation
    case timeout
}

public struct MockMedicineAssessmentRequester:
    MedicineAssessmentRequesting,
    Sendable
{
    public let behavior: MockMedicineAssessmentBehavior

    public init(
        behavior: MockMedicineAssessmentBehavior
    ) {
        self.behavior = behavior
    }

    public func assess(
        request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO {
        try Task.checkCancellation()
        switch behavior {
        case let .success(response),
             let .ambiguousMedicine(response),
             let .knowledgeSourceWarning(response),
             let .redRisk(response):
            return response
        case let .incompleteHealthProfile(requestID):
            throw ClientAPIError(
                error: APIErrorDTO(
                    code: .invalidUserProfile,
                    message: "Health profile is incomplete.",
                    requestID: requestID,
                    details: nil
                )
            )
        case .malformedResponse:
            throw ClientTransportError
                .malformedResponse
        case .cancellation:
            throw CancellationError()
        case .timeout:
            throw ClientTransportError.timedOut(
                ClientRequestTimeout(
                    endpoint: .medicineAssess,
                    timeoutSeconds: nil
                )
            )
        }
    }
}

public enum MockLocationAssessmentBehavior:
    Sendable,
    Equatable
{
    case response(LocationAssessmentResponseDTO)
    case apiError(APIErrorDTO)
    case malformedResponse
    case cancellation
    case timeout
}

public struct MockLocationAssessmentRequester:
    LocationAssessmentRequesting,
    Sendable
{
    public let behavior: MockLocationAssessmentBehavior

    public init(
        behavior: MockLocationAssessmentBehavior
    ) {
        self.behavior = behavior
    }

    public func assess(
        request: LocationAssessmentRequestDTO
    ) async throws -> LocationAssessmentResponseDTO {
        try Task.checkCancellation()
        switch behavior {
        case let .response(response):
            return response
        case let .apiError(error):
            throw ClientAPIError(error: error)
        case .malformedResponse:
            throw ClientTransportError
                .malformedResponse
        case .cancellation:
            throw CancellationError()
        case .timeout:
            throw ClientTransportError.timedOut(
                ClientRequestTimeout(
                    endpoint: .locationAssess,
                    timeoutSeconds: nil
                )
            )
        }
    }
}
