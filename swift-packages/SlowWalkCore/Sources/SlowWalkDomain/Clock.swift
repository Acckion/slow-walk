import Foundation

/// Injectable wall-clock boundary shared by deterministic health-context logic.
public protocol Clock: Sendable {
    func now() -> Date
}
