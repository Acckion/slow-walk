import Foundation
import SlowWalkDomain

/// API v1 request shared by clients and the Swift server.
public struct RiskAssessmentRequestDTO: Codable, Sendable, Equatable, Hashable {
    public let medicine: Medicine
    public let userProfile: UserHealthProfile
    public let recentRecords: [MedicationRecord]
    public let scanEvent: MedicineScanEvent
    public let requestID: UUID
    public let apiVersion: String

    public init(
        medicine: Medicine,
        userProfile: UserHealthProfile,
        recentRecords: [MedicationRecord],
        scanEvent: MedicineScanEvent,
        requestID: UUID,
        apiVersion: String
    ) {
        self.medicine = medicine
        self.userProfile = userProfile
        self.recentRecords = recentRecords
        self.scanEvent = scanEvent
        self.requestID = requestID
        self.apiVersion = apiVersion
    }
}

/// API v1 response shared by clients and the Swift server.
public struct RiskAssessmentResponseDTO: Codable, Sendable, Equatable, Hashable {
    public let requestID: UUID
    public let assessment: RiskAssessment
    public let sourceReferences: [SourceReference]
    public let generatedAt: Date
    public let apiVersion: String

    public init(
        requestID: UUID,
        assessment: RiskAssessment,
        sourceReferences: [SourceReference],
        generatedAt: Date,
        apiVersion: String
    ) {
        self.requestID = requestID
        self.assessment = assessment
        self.sourceReferences = sourceReferences
        self.generatedAt = generatedAt
        self.apiVersion = apiVersion
    }
}

/// Stable API metadata.
public enum SlowWalkAPI {
    public static let version = "v1"
}
