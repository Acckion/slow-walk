import Foundation

public struct GeoPoint: Codable, Sendable, Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct LocationSample: Codable, Sendable, Equatable, Hashable {
    public let point: GeoPoint
    public let recordedAt: Date
    public let horizontalAccuracyMeters: Double?
    public let speedMetersPerSecond: Double?
    public let source: String?

    public init(
        point: GeoPoint,
        recordedAt: Date,
        horizontalAccuracyMeters: Double?,
        speedMetersPerSecond: Double? = nil,
        source: String? = nil
    ) {
        self.point = point
        self.recordedAt = recordedAt
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.source = source
    }
}

public struct Destination: Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let point: GeoPoint
    public let geofenceRadiusMeters: Double

    public init(
        id: String,
        name: String,
        point: GeoPoint,
        geofenceRadiusMeters: Double
    ) {
        self.id = id
        self.name = name
        self.point = point
        self.geofenceRadiusMeters = geofenceRadiusMeters
    }
}

public enum LocationAccuracy:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Equatable,
    Hashable
{
    case excellent
    case good
    case reduced
    case insufficient
    case missing
}

public enum LocationRiskLevel:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Comparable,
    Equatable,
    Hashable
{
    case green
    case yellow
    case orange
    case red

    public static func < (
        lhs: LocationRiskLevel,
        rhs: LocationRiskLevel
    ) -> Bool {
        lhs.severityRank < rhs.severityRank
    }

    private var severityRank: Int {
        switch self {
        case .green:
            0
        case .yellow:
            1
        case .orange:
            2
        case .red:
            3
        }
    }
}

public enum LocationRiskReasonCode:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Equatable,
    Hashable
{
    case arrivedAtDestination = "arrived_at_destination"
    case progressingTowardDestination = "progressing_toward_destination"
    case insufficientLocationHistory = "insufficient_location_history"
    case locationDataStale = "location_data_stale"
    case locationAccuracyInsufficient = "location_accuracy_insufficient"
    case invalidLocationSample = "invalid_location_sample"
    case samplesOutOfOrder = "samples_out_of_order"
    case implausibleLocationJump = "implausible_location_jump"
    case prolongedStop = "prolonged_stop"
    case movingAway = "moving_away"
    case multipleHighRiskSignals = "multiple_high_risk_signals"
}

public struct LocationRiskReason:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let code: LocationRiskReasonCode
    public let message: String
    public let evidence: String
    public let ruleIdentifier: String

    public init(
        code: LocationRiskReasonCode,
        message: String,
        evidence: String,
        ruleIdentifier: String
    ) {
        self.code = code
        self.message = message
        self.evidence = evidence
        self.ruleIdentifier = ruleIdentifier
    }
}

public enum LocationRecommendedAction:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Equatable,
    Hashable
{
    case continueTowardDestination = "continue_toward_destination"
    case confirmArrival = "confirm_arrival"
    case stopInSafePlace = "stop_in_safe_place"
    case recheckLocation = "recheck_location"
    case confirmDirection = "confirm_direction"
    case contactFamilyOrStaff = "contact_family_or_staff"
}

public enum LocationDataQualityStatus:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Equatable,
    Hashable
{
    case valid
    case warning
    case insufficient
    case invalid
}

public enum LocationDataQualityIssueSeverity:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Equatable,
    Hashable
{
    case warning
    case error
}

public enum LocationDataQualityIssueCode:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Equatable,
    Hashable
{
    case invalidLatitude = "INVALID_LATITUDE"
    case invalidLongitude = "INVALID_LONGITUDE"
    case nonFiniteCoordinate = "NON_FINITE_COORDINATE"
    case futureSample = "FUTURE_LOCATION_SAMPLE"
    case staleSample = "STALE_LOCATION_SAMPLE"
    case accuracyMissing = "LOCATION_ACCURACY_MISSING"
    case accuracyInvalid = "LOCATION_ACCURACY_INVALID"
    case accuracyInsufficient = "LOCATION_ACCURACY_INSUFFICIENT"
    case samplesOutOfOrder = "LOCATION_SAMPLES_OUT_OF_ORDER"
    case implausibleJump = "IMPLAUSIBLE_LOCATION_JUMP"
    case invalidSpeed = "INVALID_LOCATION_SPEED"
    case insufficientSamples = "INSUFFICIENT_LOCATION_HISTORY"
}

public struct LocationDataQualityIssue:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let code: LocationDataQualityIssueCode
    public let message: String
    public let sampleIndex: Int?
    public let severity: LocationDataQualityIssueSeverity
    public let ruleIdentifier: String

    public init(
        code: LocationDataQualityIssueCode,
        message: String,
        sampleIndex: Int?,
        severity: LocationDataQualityIssueSeverity,
        ruleIdentifier: String
    ) {
        self.code = code
        self.message = message
        self.sampleIndex = sampleIndex
        self.severity = severity
        self.ruleIdentifier = ruleIdentifier
    }
}

public struct LocationDataQuality:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let status: LocationDataQualityStatus
    public let accuracy: LocationAccuracy
    public let issues: [LocationDataQualityIssue]
    public let usableSampleIndices: [Int]
    public let configurationNotices: [String]

    public init(
        status: LocationDataQualityStatus,
        accuracy: LocationAccuracy,
        issues: [LocationDataQualityIssue],
        usableSampleIndices: [Int],
        configurationNotices: [String]
    ) {
        self.status = status
        self.accuracy = accuracy
        self.issues = issues
        self.usableSampleIndices = usableSampleIndices
        self.configurationNotices = configurationNotices
    }
}

public enum GeofenceState:
    String,
    Codable,
    Sendable,
    CaseIterable,
    Equatable,
    Hashable
{
    case outside
    case approaching
    case inside
}

public struct LocationAssessment:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let level: LocationRiskLevel
    public let reasons: [LocationRiskReason]
    public let recommendedActions: [LocationRecommendedAction]
    public let assessedAt: Date
    public let dataQuality: LocationDataQuality
    public let distanceToDestinationMeters: Double?
    public let isInsideDestinationGeofence: Bool
    public let requiresUserAttention: Bool
    public let requiresFamilyAttention: Bool

    public init(
        level: LocationRiskLevel,
        reasons: [LocationRiskReason],
        recommendedActions: [LocationRecommendedAction],
        assessedAt: Date,
        dataQuality: LocationDataQuality,
        distanceToDestinationMeters: Double?,
        isInsideDestinationGeofence: Bool,
        requiresUserAttention: Bool,
        requiresFamilyAttention: Bool
    ) {
        self.level = level
        self.reasons = reasons
        self.recommendedActions = recommendedActions
        self.assessedAt = assessedAt
        self.dataQuality = dataQuality
        self.distanceToDestinationMeters = distanceToDestinationMeters
        self.isInsideDestinationGeofence =
            isInsideDestinationGeofence
        self.requiresUserAttention = requiresUserAttention
        self.requiresFamilyAttention = requiresFamilyAttention
    }
}

public struct LocationActionCard:
    Codable,
    Sendable,
    Equatable,
    Hashable
{
    public let title: String
    public let primaryInstruction: String
    public let warnings: [String]
    public let recommendedActions: [LocationRecommendedAction]
    public let riskLevel: LocationRiskLevel
    public let distanceText: String?
    public let generatedAt: Date

    public init(
        title: String,
        primaryInstruction: String,
        warnings: [String],
        recommendedActions: [LocationRecommendedAction],
        riskLevel: LocationRiskLevel,
        distanceText: String?,
        generatedAt: Date
    ) {
        self.title = title
        self.primaryInstruction = primaryInstruction
        self.warnings = warnings
        self.recommendedActions = recommendedActions
        self.riskLevel = riskLevel
        self.distanceText = distanceText
        self.generatedAt = generatedAt
    }
}
