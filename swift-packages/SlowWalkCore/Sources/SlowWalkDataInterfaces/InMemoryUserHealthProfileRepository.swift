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

    public func fetch(id: UUID) async throws -> UserHealthProfile? {
        storage[id]
    }

    public func fetchAll() async throws -> [UserHealthProfile] {
        storage.values.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    public func save(_ profile: UserHealthProfile) async throws {
        storage[profile.id] = profile
    }

    public func update(_ profile: UserHealthProfile) async throws {
        guard storage[profile.id] != nil else {
            throw DataInterfaceError.profileNotFound(id: profile.id)
        }
        storage[profile.id] = profile
    }

    public func delete(id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw DataInterfaceError.profileNotFound(id: id)
        }
    }
}
