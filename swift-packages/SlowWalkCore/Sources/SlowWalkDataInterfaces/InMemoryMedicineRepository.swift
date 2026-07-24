import Foundation
import SlowWalkDomain

/// Actor-isolated medicine repository for demos and tests.
public actor InMemoryMedicineRepository: MedicineRepository, MedicineSearching {
    private var storage: [String: Medicine]

    public init(initialMedicines: [Medicine] = []) {
        var initialStorage = [String: Medicine]()
        for medicine in initialMedicines {
            initialStorage[medicine.id] = medicine
        }
        storage = initialStorage
    }

    public func medicine(id: String) async throws -> Medicine? {
        storage[id]
    }

    public func allMedicines() async throws -> [Medicine] {
        storage.values.sorted(by: Self.medicineOrder)
    }

    public func save(_ medicine: Medicine) async throws {
        storage[medicine.id] = medicine
    }

    public func searchMedicines(matching query: String) async throws -> [Medicine] {
        let normalizedQuery = Self.normalized(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return storage.values
            .filter { medicine in
                let names = [medicine.canonicalName] + medicine.aliases
                return names.contains { name in
                    Self.normalized(name).contains(normalizedQuery)
                }
            }
            .sorted(by: Self.medicineOrder)
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func medicineOrder(_ lhs: Medicine, _ rhs: Medicine) -> Bool {
        let lhsName = normalized(lhs.canonicalName)
        let rhsName = normalized(rhs.canonicalName)
        if lhsName != rhsName {
            return lhsName < rhsName
        }
        return lhs.id < rhs.id
    }
}
