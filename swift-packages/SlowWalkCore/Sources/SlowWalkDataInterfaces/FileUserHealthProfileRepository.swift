import Foundation
import SlowWalkDomain

/// Actor-isolated JSON repository for user health profiles.
public actor FileUserHealthProfileRepository:
    UserHealthProfileRepository
{
    public static let fileName = "user-health-profiles.json"
    public static let schemaVersion = 1

    private let file: JSONRepositoryFile<UserHealthProfile>

    public init(
        baseDirectory: URL,
        uuidProvider: any UUIDProviding = SystemUUIDProvider()
    ) {
        file = JSONRepositoryFile(
            baseDirectory: baseDirectory,
            fileName: Self.fileName,
            schemaVersion: Self.schemaVersion,
            uuidProvider: uuidProvider
        )
    }

    public func fetch(id: UUID) async throws -> UserHealthProfile? {
        try file.load().first { $0.id == id }
    }

    public func fetchAll() async throws -> [UserHealthProfile] {
        try file.load().sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    public func save(_ profile: UserHealthProfile) async throws {
        var profiles = try loadOrEmpty()
        profiles.removeAll { $0.id == profile.id }
        profiles.append(profile)
        try write(profiles)
    }

    public func update(_ profile: UserHealthProfile) async throws {
        var profiles = try file.load()
        guard let index = profiles.firstIndex(
            where: { $0.id == profile.id }
        ) else {
            throw DataInterfaceError.profileNotFound(id: profile.id)
        }
        profiles[index] = profile
        try write(profiles)
    }

    public func delete(id: UUID) async throws {
        var profiles = try file.load()
        guard profiles.contains(where: { $0.id == id }) else {
            throw DataInterfaceError.profileNotFound(id: id)
        }
        profiles.removeAll { $0.id == id }
        try write(profiles)
    }

    private func loadOrEmpty() throws -> [UserHealthProfile] {
        do {
            return try file.load()
        } catch JSONRepositoryError.fileNotFound {
            return []
        }
    }

    private func write(_ profiles: [UserHealthProfile]) throws {
        try file.write(
            profiles.sorted {
                $0.id.uuidString < $1.id.uuidString
            }
        )
    }
}
