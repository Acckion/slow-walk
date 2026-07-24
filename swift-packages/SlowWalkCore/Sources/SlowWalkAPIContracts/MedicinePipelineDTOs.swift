import Foundation
import SlowWalkDomain

/// API v1 request for deterministic medicine-name resolution.
public struct MedicineResolutionRequestDTO: Codable, Sendable, Equatable, Hashable {
    public let input: MedicineRecognitionInput
    public let requestID: UUID
    public let apiVersion: String

    public init(
        input: MedicineRecognitionInput,
        requestID: UUID,
        apiVersion: String
    ) {
        self.input = input
        self.requestID = requestID
        self.apiVersion = apiVersion
    }
}

/// API v1 response for a successful medicine resolution request.
public struct MedicineResolutionResponseDTO: Codable, Sendable, Equatable, Hashable {
    public let requestID: UUID
    public let resolution: MedicineResolution
    public let cacheHit: Bool
    public let cacheStatus: MedicineResolutionCacheStatus
    public let sourceDataVersion: String
    public let generatedAt: Date
    public let apiVersion: String

    public init(
        requestID: UUID,
        resolution: MedicineResolution,
        cacheHit: Bool,
        cacheStatus: MedicineResolutionCacheStatus,
        sourceDataVersion: String,
        generatedAt: Date,
        apiVersion: String
    ) {
        self.requestID = requestID
        self.resolution = resolution
        self.cacheHit = cacheHit
        self.cacheStatus = cacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.apiVersion = apiVersion
    }
}

/// API v1 request for the complete recognition-to-action-card pipeline.
///
/// The medicine itself is deliberately absent. It is resolved from the
/// server-owned catalog so a client cannot replace trusted ingredients,
/// warnings, or source references.
public struct MedicineAssessmentRequestDTO: Codable, Sendable, Equatable, Hashable {
    public let input: MedicineRecognitionInput
    public let userProfile: UserHealthProfile
    public let recentRecords: [MedicationRecord]
    public let requestID: UUID
    public let apiVersion: String

    public init(
        input: MedicineRecognitionInput,
        userProfile: UserHealthProfile,
        recentRecords: [MedicationRecord],
        requestID: UUID,
        apiVersion: String
    ) {
        self.input = input
        self.userProfile = userProfile
        self.recentRecords = recentRecords
        self.requestID = requestID
        self.apiVersion = apiVersion
    }
}

/// API v1 response from the complete medicine pipeline.
public struct MedicineAssessmentResponseDTO: Codable, Sendable, Equatable, Hashable {
    public let requestID: UUID
    public let resolution: MedicineResolution
    public let assessment: RiskAssessment?
    public let actionCard: ActionCard
    public let cacheHit: Bool
    public let cacheStatus: MedicineResolutionCacheStatus
    public let sourceDataVersion: String
    public let generatedAt: Date
    public let apiVersion: String

    public init(
        requestID: UUID,
        resolution: MedicineResolution,
        assessment: RiskAssessment?,
        actionCard: ActionCard,
        cacheHit: Bool,
        cacheStatus: MedicineResolutionCacheStatus,
        sourceDataVersion: String,
        generatedAt: Date,
        apiVersion: String
    ) {
        self.requestID = requestID
        self.resolution = resolution
        self.assessment = assessment
        self.actionCard = actionCard
        self.cacheHit = cacheHit
        self.cacheStatus = cacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.apiVersion = apiVersion
    }
}
