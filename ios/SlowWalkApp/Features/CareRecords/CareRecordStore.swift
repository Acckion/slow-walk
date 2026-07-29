import Foundation
import SlowWalkDomain

/// Reads and appends care records.
///
/// `CompanionSessionModel` depends on this protocol rather than on the
/// in-memory store, so a persistent repository can replace the implementation
/// without touching the session logic. `CareRecordsView` reads the concrete
/// store through `AppEnvironment` so SwiftUI's Observation tracking sees the
/// `events` change; swapping the implementation therefore also means updating
/// that one property on `AppEnvironment`.
protocol CareRecordStoring: AnyObject {
    var events: [CareRecordEvent] { get }
    func append(_ kind: CareRecordEventKind)
}

/// In-memory care record store for the demo flow.
///
/// Nothing is written to disk. The persistent implementation is intentionally
/// deferred: `ios/README.md` records that the current JSON repository has no
/// Apple Data Protection, so real health data must not be stored yet.
@Observable
final class InMemoryCareRecordStore: CareRecordStoring {
    private(set) var events: [CareRecordEvent] = []

    private let clock: any SlowWalkDomain.Clock
    private let makeID: () -> UUID

    init(
        clock: any SlowWalkDomain.Clock,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.clock = clock
        self.makeID = makeID
    }

    func append(_ kind: CareRecordEventKind) {
        events.append(
            CareRecordEvent(
                id: makeID(),
                occurredAt: clock.now(),
                kind: kind
            )
        )
    }
}
