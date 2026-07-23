import Foundation

/// Traceable source metadata for medicine information.
public struct SourceReference: Codable, Sendable, Equatable, Hashable {
    public let sourceName: String
    public let documentTitle: String
    public let optionalURL: URL?
    public let retrievedAt: Date
    public let versionOrDate: String

    public init(
        sourceName: String,
        documentTitle: String,
        optionalURL: URL?,
        retrievedAt: Date,
        versionOrDate: String
    ) {
        self.sourceName = sourceName
        self.documentTitle = documentTitle
        self.optionalURL = optionalURL
        self.retrievedAt = retrievedAt
        self.versionOrDate = versionOrDate
    }
}
