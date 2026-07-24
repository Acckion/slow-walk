import SlowWalkDomain

/// Voice output boundary for accessible risk summaries.
protocol RiskResultSpeaking: Sendable {
    func speak(_ assessment: RiskAssessment) async throws
    func stop() async
}

