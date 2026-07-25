import Foundation
import SlowWalkLocationRisk

public struct LocationAssessmentRequestDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let destination: Destination
    public let recentSamples: [LocationSample]
    public let requestID: UUID
    public let apiVersion: String

    public init(
        destination: Destination,
        recentSamples: [LocationSample],
        requestID: UUID,
        apiVersion: String
    ) {
        self.destination = destination
        self.recentSamples = recentSamples
        self.requestID = requestID
        self.apiVersion = apiVersion
    }
}

public struct LocationAssessmentResponseDTO:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let requestID: UUID
    public let assessment: LocationAssessment
    public let actionCard: LocationActionCard
    public let warnings: [String]
    public let generatedAt: Date
    public let apiVersion: String

    public init(
        requestID: UUID,
        assessment: LocationAssessment,
        actionCard: LocationActionCard,
        warnings: [String],
        generatedAt: Date,
        apiVersion: String
    ) {
        self.requestID = requestID
        self.assessment = assessment
        self.actionCard = actionCard
        self.warnings = warnings
        self.generatedAt = generatedAt
        self.apiVersion = apiVersion
    }
}
