import Foundation

/// Result state from the client-side recognition pipeline.
public enum RecognitionStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case recognized
    case uncertain
    case failed
}

/// Immutable medicine scan metadata. Image data is deliberately excluded.
public struct MedicineScanEvent: Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let recognizedText: String
    public let candidateMedicineID: String?
    public let confidence: Double
    public let scannedAt: Date
    public let recognitionStatus: RecognitionStatus

    public init(
        id: UUID,
        recognizedText: String,
        candidateMedicineID: String?,
        confidence: Double,
        scannedAt: Date,
        recognitionStatus: RecognitionStatus
    ) {
        self.id = id
        self.recognizedText = recognizedText
        self.candidateMedicineID = candidateMedicineID
        self.confidence = confidence
        self.scannedAt = scannedAt
        self.recognitionStatus = recognitionStatus
    }
}
