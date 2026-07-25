import Foundation
import SlowWalkDomain
import SlowWalkMedicineKnowledge

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
    public let resolutionCacheStatus: MedicineResolutionCacheStatus
    public let knowledgeCacheStatus: MedicineKnowledgeCacheStatus?
    public let sourceDataVersion: String
    public let generatedAt: Date
    public let apiVersion: String
    public let medicineKnowledge:
        MedicineKnowledgeSearchResult?

    public init(
        requestID: UUID,
        resolution: MedicineResolution,
        cacheHit: Bool,
        resolutionCacheStatus: MedicineResolutionCacheStatus,
        knowledgeCacheStatus: MedicineKnowledgeCacheStatus? = nil,
        sourceDataVersion: String,
        generatedAt: Date,
        apiVersion: String,
        medicineKnowledge:
            MedicineKnowledgeSearchResult? = nil
    ) {
        self.requestID = requestID
        self.resolution = resolution
        self.cacheHit = cacheHit
        self.resolutionCacheStatus = resolutionCacheStatus
        self.knowledgeCacheStatus = knowledgeCacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.apiVersion = apiVersion
        self.medicineKnowledge = medicineKnowledge
    }
}

/// API v1 request for the complete recognition-to-action-card pipeline.
///
/// The medicine itself is deliberately absent. It is resolved from the
/// server-owned catalog so a client cannot replace trusted ingredients,
/// warnings, or source references.
public struct MedicineAssessmentRequestDTO: Codable, Sendable, Equatable, Hashable {
    public let input: MedicineRecognitionInput
    public let userProfile: UserHealthProfileDTO
    public let recentRecords: [MedicationRecordDTO]
    public let requestID: UUID
    public let apiVersion: String

    public init(
        input: MedicineRecognitionInput,
        userProfile: UserHealthProfileDTO,
        recentRecords: [MedicationRecordDTO],
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
    public let resolutionCacheStatus: MedicineResolutionCacheStatus
    public let knowledgeCacheStatus: MedicineKnowledgeCacheStatus?
    public let sourceDataVersion: String
    public let generatedAt: Date
    public let apiVersion: String
    public let healthContextValidation: HealthContextValidationDTO?
    public let medicineKnowledge:
        MedicineKnowledgeSearchResult?

    public init(
        requestID: UUID,
        resolution: MedicineResolution,
        assessment: RiskAssessment?,
        actionCard: ActionCard,
        cacheHit: Bool,
        resolutionCacheStatus: MedicineResolutionCacheStatus,
        knowledgeCacheStatus: MedicineKnowledgeCacheStatus? = nil,
        sourceDataVersion: String,
        generatedAt: Date,
        apiVersion: String,
        healthContextValidation: HealthContextValidationDTO? = nil,
        medicineKnowledge:
            MedicineKnowledgeSearchResult? = nil
    ) {
        self.requestID = requestID
        self.resolution = resolution
        self.assessment = assessment
        self.actionCard = actionCard
        self.cacheHit = cacheHit
        self.resolutionCacheStatus = resolutionCacheStatus
        self.knowledgeCacheStatus = knowledgeCacheStatus
        self.sourceDataVersion = sourceDataVersion
        self.generatedAt = generatedAt
        self.apiVersion = apiVersion
        self.healthContextValidation = healthContextValidation
        self.medicineKnowledge = medicineKnowledge
    }
}
