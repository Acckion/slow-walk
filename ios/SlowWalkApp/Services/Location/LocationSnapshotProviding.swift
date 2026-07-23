import Foundation

struct LocationSnapshot: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let capturedAt: Date
}

/// Minimal location boundary; CoreLocation types stay inside the adapter.
protocol LocationSnapshotProviding: Sendable {
    func currentSnapshot() async throws -> LocationSnapshot
}

