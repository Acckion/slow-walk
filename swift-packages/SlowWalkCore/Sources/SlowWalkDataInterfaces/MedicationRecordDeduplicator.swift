import Foundation
import SlowWalkDomain

enum MedicationRecordDeduplicator {
    static func deduplicate(
        _ records: [MedicationRecord],
        duplicateWindow: TimeInterval = 60
    ) -> (records: [MedicationRecord], removedCount: Int) {
        var seen = Set<RecordKey>()
        let sorted = records.sorted(by: recordOrder)
        let unique = sorted.filter { record in
            let bucket = Int(
                floor(
                    record.recordedAt.timeIntervalSince1970
                        / duplicateWindow
                )
            )
            let key = RecordKey(
                medicineID: normalized(record.medicineID),
                ingredients: record.activeIngredientIDs
                    .map(normalized)
                    .filter { !$0.isEmpty }
                    .sorted(),
                eventType: record.eventType,
                bucket: bucket
            )
            return seen.insert(key).inserted
        }
        return (unique, sorted.count - unique.count)
    }

    static func recordOrder(
        _ lhs: MedicationRecord,
        _ rhs: MedicationRecord
    ) -> Bool {
        if lhs.recordedAt != rhs.recordedAt {
            return lhs.recordedAt < rhs.recordedAt
        }
        if lhs.medicineID != rhs.medicineID {
            return lhs.medicineID < rhs.medicineID
        }
        if lhs.eventType != rhs.eventType {
            return lhs.eventType.rawValue < rhs.eventType.rawValue
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
    }
}

private struct RecordKey: Hashable {
    let medicineID: String
    let ingredients: [String]
    let eventType: MedicationEventType
    let bucket: Int
}
