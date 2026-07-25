import Foundation
import SlowWalkAPIContracts
import SlowWalkLocationRisk
import XCTest

final class LocationRiskDTOTests: XCTestCase {
    func testLocationDTOsRoundTripWithCanonicalCoding()
        throws {
        let generatedAt = Date(
            timeIntervalSince1970: 1_784_980_800
        )
        let destination = Destination(
            id: "demo-destination",
            name: "虚构目的地",
            point: GeoPoint(
                latitude: 10,
                longitude: 20
            ),
            geofenceRadiusMeters: 50
        )
        let samples = [
            LocationSample(
                point: GeoPoint(
                    latitude: 10,
                    longitude: 20.001
                ),
                recordedAt:
                    generatedAt.addingTimeInterval(-60),
                horizontalAccuracyMeters: 10,
                speedMetersPerSecond: 1,
                source: "demo"
            ),
            LocationSample(
                point: GeoPoint(
                    latitude: 10,
                    longitude: 20.0001
                ),
                recordedAt: generatedAt,
                horizontalAccuracyMeters: 10,
                speedMetersPerSecond: 1,
                source: "demo"
            ),
        ]
        let request = LocationAssessmentRequestDTO(
            destination: destination,
            recentSamples: samples,
            requestID: fixedUUID,
            apiVersion: SlowWalkAPI.version
        )
        let quality = LocationDataQuality(
            status: .valid,
            accuracy: .excellent,
            issues: [],
            usableSampleIndices: [0, 1],
            configurationNotices:
                LocationRiskConfiguration.notices
        )
        let assessment = LocationAssessment(
            level: .green,
            reasons: [
                LocationRiskReason(
                    code: .arrivedAtDestination,
                    message: "Arrived.",
                    evidence: "Inside radius.",
                    ruleIdentifier:
                        "location-destination-geofence"
                ),
            ],
            recommendedActions: [.confirmArrival],
            assessedAt: generatedAt,
            dataQuality: quality,
            distanceToDestinationMeters: 11,
            isInsideDestinationGeofence: true,
            requiresUserAttention: false,
            requiresFamilyAttention: false
        )
        let card = LocationActionCardFactory()
            .makeCard(from: assessment)
        let response = LocationAssessmentResponseDTO(
            requestID: fixedUUID,
            assessment: assessment,
            actionCard: card,
            warnings: card.warnings,
            generatedAt: generatedAt,
            apiVersion: SlowWalkAPI.version
        )
        let envelope = LocationDTOEnvelope(
            request: request,
            response: response
        )

        let data = try SlowWalkJSONCoding.makeEncoder()
            .encode(envelope)
        let decoded = try SlowWalkJSONCoding.makeDecoder()
            .decode(
                LocationDTOEnvelope.self,
                from: data
            )
        XCTAssertEqual(decoded, envelope)
    }

    private var fixedUUID: UUID {
        UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 80
            )
        )
    }
}

private struct LocationDTOEnvelope:
    Codable,
    Equatable
{
    let request: LocationAssessmentRequestDTO
    let response: LocationAssessmentResponseDTO
}
