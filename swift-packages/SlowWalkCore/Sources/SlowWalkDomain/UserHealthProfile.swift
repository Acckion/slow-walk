import Foundation

/// Optional measurements supplied by a user or trusted source.
///
/// Values are stored for data-quality checks only. SlowWalkCore does not apply
/// diagnostic thresholds to them.
public struct BodyMetrics: Codable, Sendable, Equatable, Hashable {
    public let systolicBloodPressure: Int?
    public let diastolicBloodPressure: Int?
    public let heartRate: Int?
    public let measuredAt: Date?

    public init(
        systolicBloodPressure: Int?,
        diastolicBloodPressure: Int?,
        heartRate: Int?,
        measuredAt: Date?
    ) {
        self.systolicBloodPressure = systolicBloodPressure
        self.diastolicBloodPressure = diastolicBloodPressure
        self.heartRate = heartRate
        self.measuredAt = measuredAt
    }
}

/// User-supplied health context used by risk rules.
public struct UserHealthProfile: Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let age: Int
    public let allergies: [String]
    public let diagnosedConditions: [String]
    public let currentMedicineIngredientIDs: [String]
    public let bodyMetrics: BodyMetrics?
    public let updatedAt: Date

    public init(
        id: UUID,
        age: Int,
        allergies: [String],
        diagnosedConditions: [String],
        currentMedicineIngredientIDs: [String],
        bodyMetrics: BodyMetrics?,
        updatedAt: Date
    ) {
        self.id = id
        self.age = age
        self.allergies = allergies
        self.diagnosedConditions = diagnosedConditions
        self.currentMedicineIngredientIDs = currentMedicineIngredientIDs
        self.bodyMetrics = bodyMetrics
        self.updatedAt = updatedAt
    }
}
