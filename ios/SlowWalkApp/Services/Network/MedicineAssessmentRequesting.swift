import SlowWalkAPIContracts

/// Typed transport boundary for the governed API v1 medicine pipeline.
///
/// Implementations send only recognition evidence and health-context DTOs.
/// Trusted medicine ingredients and source references remain server-owned.
protocol MedicineAssessmentRequesting: Sendable {
    func assess(
        _ request: MedicineAssessmentRequestDTO
    ) async throws -> MedicineAssessmentResponseDTO
}
