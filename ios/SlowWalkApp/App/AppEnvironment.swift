import Foundation
import SlowWalkClientCore
import SlowWalkDomain

/// The app's composition root.
///
/// Platform implementations and demo doubles are assembled here and handed to
/// features. Views and models never construct a clock, a store, or a network
/// client themselves.
///
/// This stage wires demo data only. `ios/README.md` records which Apple
/// adapters — Vision, CoreLocation, URLSession, protected storage, speech —
/// are still unimplemented; none of them are referenced here.
@Observable
@MainActor
final class AppEnvironment {
    let clock: any SlowWalkDomain.Clock
    let plan: TodayPlan
    let capabilities: AppCapabilityManifest
    let careRecords: InMemoryCareRecordStore
    let companion: CompanionSessionModel

    init(
        clock: any SlowWalkDomain.Clock = AppSystemClock(),
        plan: TodayPlan = .demo,
        capabilities: AppCapabilityManifest = .currentDemo
    ) {
        self.clock = clock
        self.plan = plan
        self.capabilities = capabilities

        let store = InMemoryCareRecordStore(clock: clock)
        let requester = LocalMedicineAssessmentRequester(clock: clock)
        let coordinator = MedicineAssessmentCoordinator(
            recognizer: PresetMedicineTextRecognizer.medicineDemo,
            mapper: MedicineRecognitionInputMapper(
                configuration: Self.medicineMappingConfiguration
            ),
            requester: requester,
            confirmer: requester,
            clock: clock
        )
        careRecords = store
        companion = CompanionSessionModel(
            records: store,
            coordinator: coordinator,
            medicineInput: .make(at: clock.now()),
            plan: plan
        )
    }

    /// Deterministic environment for previews.
    static func preview(
        fixedDate: Date = Date(timeIntervalSince1970: 1_753_000_000)
    ) -> AppEnvironment {
        AppEnvironment(clock: AppFixedClock(fixedDate: fixedDate))
    }

    private static let medicineMappingConfiguration: MedicineRecognitionMappingConfiguration = {
        do {
            return try MedicineRecognitionMappingConfiguration(
                minimumConfidence: 0.5,
                lowConfidenceHandling: .discard
            )
        } catch {
            preconditionFailure("The fixed medicine mapping configuration is invalid: \(error)")
        }
    }()
}
