import Foundation
import SlowWalkDomain

/// Actor-isolated profile repository for demos and tests.
public actor InMemoryUserHealthProfileRepository: UserHealthProfileRepository {
    private var storage: [UUID: UserHealthProfile]

    public init(initialProfiles: [UserHealthProfile] = []) {
        var initialStorage = [UUID: UserHealthProfile]()
        for profile in initialProfiles {
            initialStorage[profile.id] = profile
        }
        storage = initialStorage
    }

    public func profile(id: UUID) async throws -> UserHealthProfile? {
        storage[id]
    }

    public func allProfiles() async throws -> [UserHealthProfile] {
        storage.values.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    public func save(_ profile: UserHealthProfile) async throws {
        storage[profile.id] = profile
    }
}
