import Foundation

/// Typed, field-level API validation detail.
public struct APIErrorDetailDTO: Codable, Sendable, Equatable, Hashable {
    public let field: String?
    public let code: String
    public let message: String

    public init(field: String?, code: String, message: String) {
        self.field = field
        self.code = code
        self.message = message
    }
}

/// Uniform API v1 error body.
public struct APIErrorDTO: Codable, Sendable, Equatable, Hashable {
    public let code: String
    public let message: String
    public let requestID: UUID
    public let details: [APIErrorDetailDTO]?

    public init(
        code: String,
        message: String,
        requestID: UUID,
        details: [APIErrorDetailDTO]?
    ) {
        self.code = code
        self.message = message
        self.requestID = requestID
        self.details = details
    }
}
