import Foundation
import SlowWalkAPIContracts
import SlowWalkDomain
import SlowWalkLocationRisk

/// Pure Swift orchestration for bounded location assessment requests.
///
/// Location risk remains server-owned; this coordinator only collects,
/// bounds, sends, and presents canonical DTOs.
public actor LocationAssessmentCoordinator {
    public private(set) var state:
        LocationAssessmentViewState = .idle

    private let sampleProvider:
        any LocationSampleProviding
    private let requestBuilder:
        any LocationAssessmentRequestBuilding
    private let requester:
        any LocationAssessmentRequesting
    private let clock: any Clock
    private let apiVersion: String
    private let minimumSampleCount: Int

    private var activeTask:
        Task<LocationAssessmentViewState, Never>?
    private var generation = 0
    private var activeGeneration: Int?

    public init(
        sampleProvider:
            any LocationSampleProviding,
        requestBuilder:
            any LocationAssessmentRequestBuilding,
        requester:
            any LocationAssessmentRequesting,
        clock: any Clock,
        apiVersion: String,
        minimumSampleCount: Int
    ) throws {
        guard minimumSampleCount > 0 else {
            throw ClientCoreConfigurationError
                .invalidMinimumSampleCount
        }
        self.sampleProvider = sampleProvider
        self.requestBuilder = requestBuilder
        self.requester = requester
        self.clock = clock
        self.apiVersion = apiVersion
        self.minimumSampleCount =
            minimumSampleCount
    }

    @discardableResult
    public func assess(
        destination: Destination,
        requestID: UUID
    ) async -> LocationAssessmentViewState {
        activeTask?.cancel()
        generation += 1
        let operationGeneration = generation
        activeGeneration = operationGeneration
        state = .collecting(startedAt: clock.now())

        let sampleProvider = self.sampleProvider
        let requestBuilder = self.requestBuilder
        let requester = self.requester
        let clock = self.clock
        let apiVersion = self.apiVersion
        let minimumSampleCount =
            self.minimumSampleCount

        let task = Task {
            do {
                try Task.checkCancellation()
                try await sampleProvider.startSampling()
                try Task.checkCancellation()
                let referenceDate = clock.now()
                let samples = await sampleProvider
                    .recentSamples(
                        asOf: referenceDate
                    )
                let request = requestBuilder.makeRequest(
                    destination: destination,
                    samples: samples,
                    requestID: requestID,
                    apiVersion: apiVersion,
                    referenceDate: referenceDate
                )
                guard request.recentSamples.count
                    >= minimumSampleCount
                else {
                    return .insufficientSamples(
                        InsufficientLocationSamples(
                            availableSampleCount:
                                request.recentSamples.count,
                            requiredSampleCount:
                                minimumSampleCount
                        )
                    )
                }

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
                return .result(
                    LocationAssessmentPresentation(
                        response: response
                    )
                )
            } catch is CancellationError {
                await sampleProvider.stopSampling()
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

    public func cancelCurrentAssessment() async {
        activeTask?.cancel()
        activeTask = nil
        activeGeneration = nil
        await sampleProvider.stopSampling()
        state = .cancelled
    }

    public func stopSampling() async {
        await sampleProvider.stopSampling()
    }

    public func clearLocationHistory() async {
        await sampleProvider.clearHistory()
    }

    public func reset() {
        activeTask?.cancel()
        activeTask = nil
        activeGeneration = nil
        state = .idle
    }

    private func transition(
        to newState: LocationAssessmentViewState,
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
