import SlowWalkDomain

/// Actor-isolated cache for demos and tests.
public actor InMemoryMedicineCache: MedicineCache {
    private var storage: [String: Medicine]

    public init(initialMedicines: [Medicine] = []) {
        var initialStorage = [String: Medicine]()
        for medicine in initialMedicines {
            initialStorage[medicine.id] = medicine
        }
        storage = initialStorage
    }

    public func cachedMedicine(id: String) async throws -> Medicine? {
        storage[id]
    }

    public func store(_ medicine: Medicine) async throws {
        storage[medicine.id] = medicine
    }

    public func removeMedicine(id: String) async throws {
        storage[id] = nil
    }

    public func removeAll() async throws {
        storage.removeAll(keepingCapacity: false)
    }
}
