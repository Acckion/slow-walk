import Foundation

/// The capabilities that are actually available in the current app build.
///
/// Keeping this in one value prevents individual screens from implying that a
/// platform adapter exists when the composition root still uses demo input.
struct AppCapabilityManifest: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        case onDevice
        case simulated
        case unavailable
    }

    let medicineRules: Mode
    let medicineInput: Mode
    let locationProgress: Mode
    let automaticArrivalReminder: Mode
    let trustedContact: Mode
    let protectedPersistence: Mode
    let remoteServer: Mode

    static let currentDemo = AppCapabilityManifest(
        medicineRules: .unavailable,
        medicineInput: .simulated,
        locationProgress: .simulated,
        automaticArrivalReminder: .unavailable,
        trustedContact: .unavailable,
        protectedPersistence: .unavailable,
        remoteServer: .unavailable
    )
}
