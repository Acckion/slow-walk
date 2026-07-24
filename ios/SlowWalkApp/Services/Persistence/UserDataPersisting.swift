import SlowWalkDomain

/// Local persistence boundary; SwiftData and JSON are outer-layer implementations.
protocol UserDataPersisting: Sendable {
    func loadUserHealthProfile() async throws -> UserHealthProfile?
    func saveUserHealthProfile(_ profile: UserHealthProfile) async throws
    func loadMedicationHistory() async throws -> [MedicationRecord]
    func saveMedicationRecord(_ record: MedicationRecord) async throws
}

