import SlowWalkAPIContracts

/// Typed transport boundary for API v1 risk assessments.
protocol RiskAssessmentRequesting: Sendable {
    func assess(
        _ request: RiskAssessmentRequestDTO
    ) async throws -> RiskAssessmentResponseDTO
}

