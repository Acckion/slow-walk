import Foundation
import SlowWalkClientCore
import SlowWalkDomain

/// The app-facing use case returns only canonical Client Core view states.
@MainActor
protocol MedicineAssessmentRunning: AnyObject {
    func assess(
        medicine: MedicineCandidate,
        requestID: UUID
    ) async -> MedicineAssessmentViewState

    func confirmMedicine(
        candidateID: String
    ) async -> MedicineAssessmentViewState

    func cancelCurrentAssessment() async
}

/// Device-local demo composition around the production coordinator and
/// `LocalMedicineAssessmentRequester`.
///
/// The read step is still explicitly scripted because Vision is out of scope.
/// Everything after the recognized text uses the real resolver, knowledge
/// pipeline, risk engine, response validator, and canonical view state.
@MainActor
final class LocalMedicineAssessmentRunner: MedicineAssessmentRunning {
    private let requester: LocalMedicineAssessmentRequester
    private let clock: any SlowWalkDomain.Clock
    private var coordinator: MedicineAssessmentCoordinator?

    init(
        requester: LocalMedicineAssessmentRequester,
        clock: any SlowWalkDomain.Clock
    ) {
        self.requester = requester
        self.clock = clock
    }

    static func demo(
        clock: any SlowWalkDomain.Clock
    ) -> LocalMedicineAssessmentRunner {
        LocalMedicineAssessmentRunner(
            requester: .demo(clock: clock),
            clock: clock
        )
    }

    func assess(
        medicine: MedicineCandidate,
        requestID: UUID
    ) async -> MedicineAssessmentViewState {
        if let coordinator {
            await coordinator.cancelCurrentAssessment()
        }

        let coordinator = MedicineAssessmentCoordinator(
            recognizer: ScriptedMedicineTextRecognizer(
                recognizedText: medicine.displayName
            ),
            mapper: MedicineRecognitionInputMapper(
                configuration: demoRecognitionConfiguration
            ),
            requester: requester,
            confirmer: requester,
            clock: clock
        )
        self.coordinator = coordinator

        let now = clock.now()
        return await coordinator.assess(
            imageInput: OCRImageInput(
                data: Data([0x01]),
                orientation: .up,
                capturedAt: now
            ),
            userProfile: demoUserProfile(at: now),
            recentRecords: [],
            requestID: requestID
        )
    }

    func confirmMedicine(
        candidateID: String
    ) async -> MedicineAssessmentViewState {
        guard let coordinator else { return .idle }
        return await coordinator.confirmMedicine(candidateID: candidateID)
    }

    func cancelCurrentAssessment() async {
        guard let coordinator else { return }
        await coordinator.cancelCurrentAssessment()
        self.coordinator = nil
    }

    private var demoRecognitionConfiguration:
        MedicineRecognitionMappingConfiguration
    {
        // These literals are statically inside the validated 0...1 range.
        // A configuration failure is a programmer error at the composition
        // root, not a recoverable user-facing assessment failure.
        do {
            return try MedicineRecognitionMappingConfiguration(
                minimumConfidence: 0.5,
                lowConfidenceHandling: .discard
            )
        } catch {
            preconditionFailure("Invalid demo recognition configuration")
        }
    }

    private func demoUserProfile(
        at date: Date
    ) -> UserHealthProfile {
        UserHealthProfile(
            id: UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 17
                )
            ),
            age: 72,
            allergies: [],
            diagnosedConditions: [],
            currentMedicineIngredientIDs: [],
            bodyMetrics: BodyMetrics(
                systolicBloodPressure: 120,
                diastolicBloodPressure: 80,
                heartRate: 70,
                measuredAt: date,
                source: "demo_data",
                deviceIdentifier: "slowwalk-demo-device"
            ),
            updatedAt: date
        )
    }
}

private struct ScriptedMedicineTextRecognizer:
    MedicineTextRecognizing,
    Sendable
{
    let recognizedText: String

    nonisolated func recognizeText(
        in input: OCRImageInput
    ) async throws -> [RecognizedTextObservation] {
        [
            RecognizedTextObservation(
                text: recognizedText,
                confidence: 0.98,
                boundingRegion: OCRBoundingRegion(
                    x: 0,
                    y: 0,
                    width: 1,
                    height: 1
                ),
                languageCode: "zh-Hans",
                observedAt: input.capturedAt
            ),
        ]
    }
}
