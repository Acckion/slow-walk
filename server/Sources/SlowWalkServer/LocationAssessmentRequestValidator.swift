import Foundation
import SlowWalkAPIContracts
import SlowWalkLocationRisk

public enum LocationRequestValidationFailure:
    Sendable,
    Equatable
{
    case invalidSample
    case stale
    case accuracyInsufficient
    case insufficientHistory

    var code: APIErrorCode {
        switch self {
        case .invalidSample:
            .invalidLocationSample
        case .stale:
            .locationDataStale
        case .accuracyInsufficient:
            .locationAccuracyInsufficient
        case .insufficientHistory:
            .insufficientLocationHistory
        }
    }

    var message: String {
        switch self {
        case .invalidSample:
            "One or more location samples are invalid."
        case .stale:
            "The supplied location data is stale."
        case .accuracyInsufficient:
            "Location accuracy is insufficient for assessment."
        case .insufficientHistory:
            "More reliable location history is required."
        }
    }
}

public struct LocationAssessmentRequestValidator:
    Sendable
{
    private let configuration: LocationRiskConfiguration
    private let dataQualityAssessor:
        any LocationDataQualityAssessing

    public init(
        configuration: LocationRiskConfiguration = .demo,
        dataQualityAssessor:
            (any LocationDataQualityAssessing)? = nil
    ) {
        self.configuration = configuration
        self.dataQualityAssessor =
            dataQualityAssessor
            ?? LocationDataQualityAssessor(
                configuration: configuration
            )
    }

    public func validateFields(
        _ request: LocationAssessmentRequestDTO
    ) -> [APIErrorDetailDTO] {
        var details = [APIErrorDetailDTO]()
        if request.destination.id.isBlank {
            details.append(
                detail(
                    field: "destination.id",
                    code: "required",
                    message: "Destination ID is required."
                )
            )
        }
        if request.destination.name.isBlank {
            details.append(
                detail(
                    field: "destination.name",
                    code: "required",
                    message: "Destination name is required."
                )
            )
        }
        let point = request.destination.point
        if !point.latitude.isFinite
            || !(-90 ... 90).contains(point.latitude) {
            details.append(
                detail(
                    field: "destination.point.latitude",
                    code: "out_of_range",
                    message:
                        "Destination latitude must be finite and between -90 and 90."
                )
            )
        }
        if !point.longitude.isFinite
            || !(-180 ... 180).contains(point.longitude) {
            details.append(
                detail(
                    field: "destination.point.longitude",
                    code: "out_of_range",
                    message:
                        "Destination longitude must be finite and between -180 and 180."
                )
            )
        }
        if !request.destination.geofenceRadiusMeters
            .isFinite
            || request.destination.geofenceRadiusMeters <= 0 {
            details.append(
                detail(
                    field:
                        "destination.geofenceRadiusMeters",
                    code: "out_of_range",
                    message:
                        "Destination geofence radius must be a positive finite value."
                )
            )
        }
        return details
    }

    public func dataQualityFailure(
        for samples: [LocationSample],
        relativeTo referenceDate: Date
    ) -> LocationRequestValidationFailure? {
        let quality = dataQualityAssessor.assess(
            samples: samples,
            relativeTo: referenceDate
        )
        let fatalCodes: Set<LocationDataQualityIssueCode> = [
            .invalidLatitude,
            .invalidLongitude,
            .nonFiniteCoordinate,
            .futureSample,
            .accuracyInvalid,
            .samplesOutOfOrder,
            .invalidSpeed,
        ]
        if quality.issues.contains(where: {
            fatalCodes.contains($0.code)
        }) {
            return .invalidSample
        }

        guard samples.count
            >= configuration.minimumSamplesForAssessment
        else {
            return .insufficientHistory
        }

        let staleIndices = Set(
            quality.issues.compactMap {
                $0.code == .staleSample
                    ? $0.sampleIndex
                    : nil
            }
        )
        if staleIndices.count == samples.count {
            return .stale
        }

        let currentIndices = Set(samples.indices)
            .subtracting(staleIndices)
        let inaccurateIndices = Set(
            quality.issues.compactMap {
                switch $0.code {
                case .accuracyMissing,
                     .accuracyInvalid,
                     .accuracyInsufficient:
                    $0.sampleIndex
                default:
                    nil
                }
            }
        )
        if !currentIndices.isEmpty,
           currentIndices.isSubset(of: inaccurateIndices) {
            return .accuracyInsufficient
        }

        if quality.usableSampleIndices.count
            < configuration.minimumSamplesForAssessment {
            return .insufficientHistory
        }
        return nil
    }

    private func detail(
        field: String,
        code: String,
        message: String
    ) -> APIErrorDetailDTO {
        APIErrorDetailDTO(
            field: field,
            code: code,
            message: message
        )
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
    }
}
