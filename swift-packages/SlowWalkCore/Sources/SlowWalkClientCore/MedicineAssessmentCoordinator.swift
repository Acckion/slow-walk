import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain

/// Pure Swift orchestration from OCR input to the canonical medicine API.
///
/// It does not resolve medicines, assess risk, retry validation failures, or
/// retain image bytes in state.
public actor MedicineAssessmentCoordinator {
    public private(set) var state:
        MedicineAssessmentViewState = .idle

    private let recognizer:
        any MedicineTextRecognizing
    private let mapper:
        MedicineRecognitionInputMapper
    private let requestBuilder:
        any MedicineAssessmentRequestBuilding
    private let requester:
        any MedicineAssessmentRequesting
    private let clock: any Clock
    private let apiVersion: String

    private var activeTask:
        Task<MedicineAssessmentViewState, Never>?
    private var generation = 0
    private var activeGeneration: Int?

    public init(
        recognizer: any MedicineTextRecognizing,
        mapper: MedicineRecognitionInputMapper,
        requestBuilder:
            any MedicineAssessmentRequestBuilding =
                MedicineAssessmentRequestBuilder(),
        requester:
            any MedicineAssessmentRequesting,
        clock: any Clock,
        apiVersion: String
    ) {
        self.recognizer = recognizer
        self.mapper = mapper
        self.requestBuilder = requestBuilder
        self.requester = requester
        self.clock = clock
        self.apiVersion = apiVersion
    }

    @discardableResult
    public func assess(
        imageInput: OCRImageInput,
        userProfile: UserHealthProfileDTO,
        recentRecords: [MedicationRecordDTO],
        requestID: UUID
    ) async -> MedicineAssessmentViewState {
        activeTask?.cancel()
        generation += 1
        let operationGeneration = generation
        activeGeneration = operationGeneration
        state = .recognizing(
            startedAt: clock.now()
        )

        let recognizer = self.recognizer
        let mapper = self.mapper
        let requestBuilder = self.requestBuilder
        let requester = self.requester
        let clock = self.clock
        let apiVersion = self.apiVersion

        let task = Task<
            MedicineAssessmentViewState,
            Never
        > {
            do {
                try Task.checkCancellation()
                let observations = try await recognizer
                    .recognizeText(in: imageInput)
                try Task.checkCancellation()
                let recognitionInput = mapper.map(
                    observations: observations,
                    capturedAt:
                        imageInput.capturedAt
                )

                guard !recognitionInput
                    .recognizedTexts.isEmpty
                else {
                    return .requiresMedicineConfirmation(
                        MedicineConfirmationRequirement(
                            reason: .noRecognizedText,
                            recognitionInput:
                                recognitionInput,
                            response: nil
                        )
                    )
                }

                let request = requestBuilder
                    .makeRequest(
                        input: recognitionInput,
                        userProfile: userProfile,
                        recentRecords:
                            recentRecords,
                        requestID: requestID,
                        apiVersion: apiVersion
                    )
                try Task.checkCancellation()
                await self.transition(
                    to: .assessing(
                        startedAt: clock.now()
                    ),
                    generation:
                        operationGeneration
                )
                let response = try await requester
                    .assess(request: request)
                try Task.checkCancellation()

                if response.resolution.status
                    == .ambiguous
                {
                    return .requiresMedicineConfirmation(
                        MedicineConfirmationRequirement(
                            reason: .ambiguousMedicine,
                            recognitionInput:
                                recognitionInput,
                            response: response
                        )
                    )
                }
                if response.resolution.status
                    != .resolved
                {
                    return .requiresMedicineConfirmation(
                        MedicineConfirmationRequirement(
                            reason: .unresolvedMedicine,
                            recognitionInput:
                                recognitionInput,
                            response: response
                        )
                    )
                }
                if response.resolution
                    .requiresUserConfirmation
                {
                    return .requiresMedicineConfirmation(
                        MedicineConfirmationRequirement(
                            reason:
                                .serverRequiresConfirmation,
                            recognitionInput:
                                recognitionInput,
                            response: response
                        )
                    )
                }

                return .result(
                    MedicineAssessmentPresentation(
                        response: response
                    )
                )
            } catch is CancellationError {
                return .cancelled
            } catch {
                return .failed(
                    ClientFailureMapper.map(error)
                )
            }
        }
        activeTask = task

        let result = await withTaskCancellationHandler(
            operation: {
                await task.value
            },
            onCancel: {
                task.cancel()
            }
        )
        if activeGeneration == operationGeneration {
            state = result
            activeTask = nil
            activeGeneration = nil
        }
        return result
    }

    public func cancelCurrentAssessment() {
        activeTask?.cancel()
        activeTask = nil
        activeGeneration = nil
        state = .cancelled
    }

    public func reset() {
        activeTask?.cancel()
        activeTask = nil
        activeGeneration = nil
        state = .idle
    }

    private func transition(
        to newState: MedicineAssessmentViewState,
        generation operationGeneration: Int
    ) {
        guard activeGeneration
            == operationGeneration
        else {
            return
        }
        state = newState
    }
}
