import Foundation
import SlowWalkDomain

/// The app's single wall-clock boundary.
///
/// `SlowWalkDataInterfaces` already provides `SystemDateProvider`, but that
/// product is not linked into the app target. Rather than widen the target's
/// dependencies for one call, the app conforms to `SlowWalkDomain.Clock`
/// directly.
struct AppSystemClock: SlowWalkDomain.Clock {
    func now() -> Date {
        Date()
    }
}

/// Deterministic clock for previews and demo walkthroughs.
struct AppFixedClock: SlowWalkDomain.Clock {
    let fixedDate: Date

    func now() -> Date {
        fixedDate
    }
}
