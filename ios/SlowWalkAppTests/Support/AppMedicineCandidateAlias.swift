@testable import SlowWalkApp

/// Kept in a file that does not import SlowWalkDomain so the App's scripted
/// candidate and Core's canonical candidate cannot become an ambiguous lookup.
typealias AppMedicineCandidate = MedicineCandidate
