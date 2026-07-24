import Foundation

/// Kind of user medication-history event.
public enum MedicationEventType: String, Codable, Sendable, CaseIterable, Hashable {
    case scanned
    case confirmedIntake = "confirmed_intake"
    /// Legacy API v1 value retained for backward compatibility.
    case taken
    case reported
}

/// Origin of a medication-history event.
public enum MedicationRecordSource: String, Codable, Sendable, CaseIterable, Hashable {
    case manualEntry = "manual_entry"
    case medicineScan = "medicine_scan"
    case demoData = "demo_data"
}

/// Immutable medication-history event.
public struct MedicationRecord: Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let medicineID: String
    public let activeIngredientIDs: [String]
    public let recordedAt: Date
    public let eventType: MedicationEventType
    public let source: MedicationRecordSource

    public init(
        id: UUID,
        medicineID: String,
        activeIngredientIDs: [String],
        recordedAt: Date,
        eventType: MedicationEventType,
        source: MedicationRecordSource
    ) {
        self.id = id
        self.medicineID = medicineID
        self.activeIngredientIDs = activeIngredientIDs
        self.recordedAt = recordedAt
        self.eventType = eventType
        self.source = source
    }
}
