import Foundation
import SlowWalkDomain

enum RuleSupport {
    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func normalizedSet(_ values: [String]) -> Set<String> {
        Set(values.map(normalized).filter { !$0.isEmpty })
    }

    static func matchingRecords(
        in context: MedicationRiskContext,
        noEarlierThan lowerBound: Date? = nil,
        noLaterThan upperBound: Date
    ) -> [MedicationRecord] {
        let medicineID = normalized(context.medicine.id)
        let medicineIngredients = normalizedSet(context.medicine.activeIngredientIDs)

        return uniqueRecords(context.recentRecords).filter { record in
            guard record.recordedAt <= upperBound else {
                return false
            }
            if let lowerBound, record.recordedAt < lowerBound {
                return false
            }

            let sameMedicine = normalized(record.medicineID) == medicineID
            let recordIngredients = normalizedSet(record.activeIngredientIDs)
            let overlappingIngredient = !recordIngredients.isDisjoint(with: medicineIngredients)
            return sameMedicine || overlappingIngredient
        }
    }

    static func uniqueRecords(_ records: [MedicationRecord]) -> [MedicationRecord] {
        var seenIDs = Set<UUID>()
        return records
            .sorted(by: canonicalRecordOrder)
            .filter { seenIDs.insert($0.id).inserted }
    }

    private static func canonicalRecordOrder(
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
        if lhs.source != rhs.source {
            return lhs.source.rawValue < rhs.source.rawValue
        }

        let lhsIngredients = lhs.activeIngredientIDs.sorted().joined(separator: "\u{1F}")
        let rhsIngredients = rhs.activeIngredientIDs.sorted().joined(separator: "\u{1F}")
        if lhsIngredients != rhsIngredients {
            return lhsIngredients < rhsIngredients
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
