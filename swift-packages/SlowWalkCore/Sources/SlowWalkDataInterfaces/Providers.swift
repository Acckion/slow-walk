import Foundation

/// Injectable wall-clock date source.
public protocol DateProviding: Sendable {
    func now() -> Date
}

/// The single production boundary at which the current wall-clock date is read.
public struct SystemDateProvider: DateProviding, Sendable {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

/// Deterministic date source for tests and demos.
public struct FixedDateProvider: DateProviding, Sendable, Equatable {
    public let fixedDate: Date

    public init(fixedDate: Date) {
        self.fixedDate = fixedDate
    }

    public func now() -> Date {
        fixedDate
    }
}

/// Concise aliases used by application composition and tests.
public typealias SystemClock = SystemDateProvider
public typealias FixedClock = FixedDateProvider

/// Injectable UUID creation boundary.
public protocol UUIDProviding: Sendable {
    func makeUUID() -> UUID
}

/// The single production boundary at which random UUIDs are created.
public struct SystemUUIDProvider: UUIDProviding, Sendable {
    public init() {}

    public func makeUUID() -> UUID {
        UUID()
    }
}

/// Deterministic UUID source for tests and demos.
public struct FixedUUIDProvider: UUIDProviding, Sendable, Equatable {
    public let fixedUUID: UUID

    public init(fixedUUID: UUID) {
        self.fixedUUID = fixedUUID
    }

    public func makeUUID() -> UUID {
        fixedUUID
    }
}
