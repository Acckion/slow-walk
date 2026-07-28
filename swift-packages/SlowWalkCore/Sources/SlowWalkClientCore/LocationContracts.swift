import Foundation
import SlowWalkAPIContracts
import SlowWalkLocationRisk

/// Platform-neutral authorization state. Apple adapters map their framework
/// values at the edge.
public enum LocationAuthorizationState:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case notDetermined = "not_determined"
    case denied
    case restricted
    case authorized
}
public enum LocationServiceAvailability:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Hashable
{
    case available
    case servicesDisabled = "services_disabled"
    case temporarilyUnavailable =
        "temporarily_unavailable"
}

public struct LocationSamplingStatus:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let authorization:
        LocationAuthorizationState
    public let availability:
        LocationServiceAvailability
    public let preciseLocationAvailable: Bool?

    public init(
        authorization: LocationAuthorizationState,
        availability: LocationServiceAvailability,
        preciseLocationAvailable: Bool?
    ) {
        self.authorization = authorization
        self.availability = availability
        self.preciseLocationAvailable =
            preciseLocationAvailable
    }
}

/// Cross-platform location sampling boundary.
///
/// Implementations return an already bounded history and never expose
/// CoreLocation/MapKit types.
public protocol LocationSampleProviding: Sendable {
    func startSampling() async throws
    func stopSampling() async
    func recentSamples(
        asOf referenceDate: Date
    ) async -> [LocationSample]
    func clearHistory() async
    func currentStatus() async
        -> LocationSamplingStatus
}

public protocol LocationAssessmentRequestBuilding:
    Sendable
{
    func makeRequest(
        destination: Destination,
        samples: [LocationSample],
        requestID: UUID,
        apiVersion: String,
        referenceDate: Date
    ) -> LocationAssessmentRequestDTO
}

public struct LocationAssessmentRequestBuilder:
    LocationAssessmentRequestBuilding,
    Sendable
{
    public let historyConfiguration:
        LocationHistoryConfiguration

    public init(
        historyConfiguration:
            LocationHistoryConfiguration
    ) {
        self.historyConfiguration =
            historyConfiguration
    }

    public func makeRequest(
        destination: Destination,
        samples: [LocationSample],
        requestID: UUID,
        apiVersion: String,
        referenceDate: Date
    ) -> LocationAssessmentRequestDTO {
        LocationAssessmentRequestDTO(
            destination: destination,
            recentSamples: BoundedLocationSamples
                .normalize(
                    samples,
                    asOf: referenceDate,
                    configuration:
                        historyConfiguration
                ),
            requestID: requestID,
            apiVersion: apiVersion
        )
    }
}
