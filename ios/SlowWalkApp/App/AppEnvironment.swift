import Foundation
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
    let careRecords: InMemoryCareRecordStore
    let companion: CompanionSessionModel

    init(
        clock: any SlowWalkDomain.Clock = AppSystemClock(),
        plan: TodayPlan = .demo,
        simulator: MockMedicineScanSimulator = .demo
    ) {
        self.clock = clock
        self.plan = plan

        let store = InMemoryCareRecordStore(clock: clock)
        careRecords = store
        companion = CompanionSessionModel(
            records: store,
            simulator: simulator,
            plan: plan
        )
    }

    /// Deterministic environment for previews.
    static func preview(
        fixedDate: Date = Date(timeIntervalSince1970: 1_753_000_000)
    ) -> AppEnvironment {
        AppEnvironment(clock: AppFixedClock(fixedDate: fixedDate))
    }
}
