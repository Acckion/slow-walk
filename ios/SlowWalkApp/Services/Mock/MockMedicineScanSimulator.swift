import Foundation

/// Drives the demo medicine-reading step without any camera or OCR.
///
/// The real reader will be a `MedicineTextRecognizing` adapter backed by
/// Vision, injected at the composition root. This simulator exists so the
/// companion flow — including one failed read and its recovery — can be walked
/// through and reviewed before any platform capability is wired up.
///
/// DEMO DATA — NOT FOR CLINICAL USE.
struct MockMedicineScanSimulator {
    /// What the next simulated read should do.
    enum Outcome: Equatable, Hashable {
        case doesNotSucceed(MedicineReadSetback)
        case findsCandidates([MedicineCandidate])
    }

    /// Outcomes in the order they are handed out, one per attempt.
    ///
    /// The default script shows a first read that does not succeed, so the
    /// recovery path is part of the main walkthrough rather than an edge case.
    let scriptedOutcomes: [Outcome]

    static let demo = MockMedicineScanSimulator(
        scriptedOutcomes: [
            .doesNotSucceed(.textNotLegible),
            .findsCandidates(MedicineCandidate.demoCandidates),
        ]
    )

    /// The outcome for a given attempt. The last entry repeats so a person can
    /// retry as many times as they like without hitting a dead end.
    func outcome(forAttemptNumber attemptNumber: Int) -> Outcome? {
        guard !scriptedOutcomes.isEmpty else { return nil }
        let index = min(max(attemptNumber, 1), scriptedOutcomes.count) - 1
        return scriptedOutcomes[index]
    }

    /// How long the simulated read appears to take.
    static let simulatedReadDuration = Duration.milliseconds(900)
}
