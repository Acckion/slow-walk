import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain

/// Pure Swift orchestration from OCR input to canonical medicine view state.
///
/// It owns cancellation, response validation, candidate-confirmation context,
/// and observable state updates. It never retains image bytes in view state.
public actor MedicineAssessmentCoordinator {
    private struct OperationOutcome: Sendable {
        let state: MedicineAssessmentViewState
        let pendingRequest: MedicineAssessmentRequestDTO?
    }

    private struct PendingConfirmation: Sendable {
        let request: MedicineAssessmentRequestDTO
        let candidateIDs: Set<String>
    }

    public private(set) var state: MedicineAssessmentViewState = .idle

    private let recognizer: any MedicineTextRecognizing
    private let mapper: MedicineRecognitionInputMapper
    private let requestBuilder: any MedicineAssessmentRequestBuilding
    private let requester: any MedicineAssessmentRequesting
    private let confirmer: (any MedicineCandidateConfirming)?
    private let responseValidator: MedicineAssessmentResponseValidator
    private let clock: any Clock
    private let apiVersion: String

    private var activeTask: Task<OperationOutcome, Never>?
    private var generation: UInt64 = 0
    private var activeGeneration: UInt64?
    private var pendingConfirmation: PendingConfirmation?
    private var stateContinuations:
        [UUID: AsyncStream<MedicineAssessmentStateUpdate>.Continuation] = [:]

    public init(
        recognizer: any MedicineTextRecognizing,
        mapper: MedicineRecognitionInputMapper,
        requestBuilder: any MedicineAssessmentRequestBuilding =
            MedicineAssessmentRequestBuilder(),
        requester: any MedicineAssessmentRequesting,
        confirmer: (any MedicineCandidateConfirming)? = nil,
        responseValidator: MedicineAssessmentResponseValidator = .init(),
        clock: any Clock,
        apiVersion: String = SlowWalkAPI.version
    ) {
        self.recognizer = recognizer
        self.mapper = mapper
        self.requestBuilder = requestBuilder
        self.requester = requester
        self.confirmer = confirmer
        self.responseValidator = responseValidator
        self.clock = clock
        self.apiVersion = apiVersion
    }

    /// Starts an assessment from domain models used by an on-device client.
    ///
    /// DTO conversion stays inside ClientCore so an app composition root does
    /// not need to treat the local pipeline as an HTTP service.
    @discardableResult
    public func assess(
        imageInput: OCRImageInput,
        userProfile: UserHealthProfile,
        recentRecords: [MedicationRecord],
        requestID: UUID
    ) async -> MedicineAssessmentViewState {
        await assess(
            imageInput: imageInput,
            userProfile: UserHealthProfileDTO(userProfile),
            recentRecords: recentRecords.map(MedicationRecordDTO.init),
            requestID: requestID
        )
    }

    /// State stream for a MainActor facade or another presentation consumer.
    /// The current value is yielded immediately; later updates are buffered so
    /// short recognizing/assessing transitions are not lost.
    public func stateUpdates()
        -> AsyncStream<MedicineAssessmentStateUpdate>
    {
        let id = UUID()
        let pair = AsyncStream<MedicineAssessmentStateUpdate>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )
        stateContinuations[id] = pair.continuation
        pair.continuation.yield(currentStateUpdate)
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStateContinuation(id) }
        }
        return pair.stream
    }

    public var currentStateUpdate: MedicineAssessmentStateUpdate {
        MedicineAssessmentStateUpdate(
            sequenceNumber: generation,
            state: state
        )
    }

    @discardableResult
    public func assess(
        imageInput: OCRImageInput,
        userProfile: UserHealthProfileDTO,
        recentRecords: [MedicationRecordDTO],
        requestID: UUID
    ) async -> MedicineAssessmentViewState {
        beginOperation(with: .recognizing(startedAt: clock.now()))
        pendingConfirmation = nil
        let operationGeneration = generation

        let recognizer = self.recognizer
        let mapper = self.mapper
        let requestBuilder = self.requestBuilder
        let requester = self.requester
        let responseValidator = self.responseValidator
        let clock = self.clock
        let apiVersion = self.apiVersion

        let task = Task<OperationOutcome, Never> {
            do {
                try Task.checkCancellation()
                let observations = try await recognizer.recognizeText(
                    in: imageInput
                )
                try Task.checkCancellation()
                let recognitionInput = mapper.map(
                    observations: observations,
                    capturedAt: imageInput.capturedAt
                )

                guard !recognitionInput.recognizedTexts.isEmpty else {
                    return OperationOutcome(
                        state: .requiresMedicineConfirmation(
                            MedicineConfirmationRequirement(
                                reason: .noRecognizedText,
                                recognitionInput: recognitionInput,
                                response: nil
                            )
                        ),
                        pendingRequest: nil
                    )
                }

                let request = requestBuilder.makeRequest(
                    input: recognitionInput,
                    userProfile: userProfile,
                    recentRecords: recentRecords,
                    requestID: requestID,
                    apiVersion: apiVersion
                )
                try Task.checkCancellation()
                self.transition(
                    to: .assessing(startedAt: clock.now()),
                    generation: operationGeneration
                )
                let response = try await requester.assess(request: request)
                try Task.checkCancellation()
                try responseValidator.validate(response, for: request)

                let nextState = Self.viewState(
                    response: response,
                    recognitionInput: recognitionInput
                )
                let pendingRequest: MedicineAssessmentRequestDTO?
                if Self.needsCandidateConfirmation(nextState) {
                    pendingRequest = request
                } else {
                    pendingRequest = nil
                }
                return OperationOutcome(
                    state: nextState,
                    pendingRequest: pendingRequest
                )
            } catch is CancellationError {
                return OperationOutcome(
                    state: .cancelled,
                    pendingRequest: nil
                )
            } catch {
                return OperationOutcome(
                    state: .failed(ClientFailureMapper.map(error)),
                    pendingRequest: nil
                )
            }
        }
        activeTask = task
        return await finish(task, generation: operationGeneration)
    }

    /// Confirms one candidate from the current confirmation requirement.
    @discardableResult
    public func confirmMedicine(
        candidateID: String
    ) async -> MedicineAssessmentViewState {
        guard let pendingConfirmation,
            pendingConfirmation.candidateIDs.contains(candidateID),
            let confirmer
        else {
            return state
        }

        beginOperation(with: .assessing(startedAt: clock.now()))
        let operationGeneration = generation
        let request = pendingConfirmation.request
        let responseValidator = self.responseValidator

        let task = Task<OperationOutcome, Never> {
            do {
                try Task.checkCancellation()
                let response = try await confirmer.confirmMedicine(
                    command: MedicineCandidateConfirmationCommand(
                        originalRequestID: request.requestID,
                        candidateID: candidateID
                    )
                )
                try Task.checkCancellation()
                try responseValidator.validate(response, for: request)
                let nextState = Self.viewState(
                    response: response,
                    recognitionInput: request.input
                )
                return OperationOutcome(
                    state: nextState,
                    pendingRequest:
                        Self.needsCandidateConfirmation(nextState)
                        ? request
                        : nil
                )
            } catch is CancellationError {
                return OperationOutcome(
                    state: .cancelled,
                    pendingRequest: nil
                )
            } catch {
                return OperationOutcome(
                    state: .failed(ClientFailureMapper.map(error)),
                    pendingRequest: nil
                )
            }
        }
        activeTask = task
        return await finish(task, generation: operationGeneration)
    }

    public func cancelCurrentAssessment() {
        activeTask?.cancel()
        activeTask = nil
        activeGeneration = nil
        pendingConfirmation = nil
        publish(.cancelled)
    }

    public func reset() {
        activeTask?.cancel()
        activeTask = nil
        activeGeneration = nil
        pendingConfirmation = nil
        generation += 1
        publish(.idle)
    }

    private func beginOperation(with initialState: MedicineAssessmentViewState) {
        activeTask?.cancel()
        generation += 1
        activeGeneration = generation
        publish(initialState)
    }

    private func finish(
        _ task: Task<OperationOutcome, Never>,
        generation operationGeneration: UInt64
    ) async -> MedicineAssessmentViewState {
        let outcome = await withTaskCancellationHandler(
            operation: { await task.value },
            onCancel: { task.cancel() }
        )
        if activeGeneration == operationGeneration {
            if let request = outcome.pendingRequest,
                case .requiresMedicineConfirmation(let requirement) =
                    outcome.state,
                let response = requirement.response
            {
                pendingConfirmation = PendingConfirmation(
                    request: request,
                    candidateIDs: Set(
                        response.resolution.candidates.map {
                            $0.medicine.id
                        }
                    )
                )
            } else {
                pendingConfirmation = nil
            }
            publish(outcome.state)
            activeTask = nil
            activeGeneration = nil
        }
        return outcome.state
    }

    private func transition(
        to newState: MedicineAssessmentViewState,
        generation operationGeneration: UInt64
    ) {
        guard activeGeneration == operationGeneration else { return }
        publish(newState)
    }

    private func publish(_ newState: MedicineAssessmentViewState) {
        state = newState
        let update = currentStateUpdate
        for continuation in stateContinuations.values {
            continuation.yield(update)
        }
    }

    private func removeStateContinuation(_ id: UUID) {
        stateContinuations[id] = nil
    }

    private static func needsCandidateConfirmation(
        _ state: MedicineAssessmentViewState
    ) -> Bool {
        guard case .requiresMedicineConfirmation(let requirement) = state,
            let response = requirement.response
        else {
            return false
        }
        switch requirement.reason {
        case .ambiguousMedicine, .unresolvedMedicine:
            return !response.resolution.candidates.isEmpty
        case .noRecognizedText, .serverRequiresConfirmation:
            return false
        }
    }

    private static func viewState(
        response: MedicineAssessmentResponseDTO,
        recognitionInput: MedicineRecognitionInput
    ) -> MedicineAssessmentViewState {
        if response.resolution.status == .ambiguous {
            return .requiresMedicineConfirmation(
                MedicineConfirmationRequirement(
                    reason: .ambiguousMedicine,
                    recognitionInput: recognitionInput,
                    response: response
                )
            )
        }
        if response.resolution.status != .resolved {
            return .requiresMedicineConfirmation(
                MedicineConfirmationRequirement(
                    reason: .unresolvedMedicine,
                    recognitionInput: recognitionInput,
                    response: response
                )
            )
        }
        if response.resolution.requiresUserConfirmation {
            return .requiresMedicineConfirmation(
                MedicineConfirmationRequirement(
                    reason: .serverRequiresConfirmation,
                    recognitionInput: recognitionInput,
                    response: response
                )
            )
        }
        return .result(MedicineAssessmentPresentation(response: response))
    }
}
