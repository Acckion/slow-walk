import Foundation
import SlowWalkDomain

/// Apple-platform OCR adapter used by the medicine scanner feature.
protocol MedicineTextRecognizing: Sendable {
    func recognizeMedicine(
        in imageData: Data,
        capturedAt: Date
    ) async throws -> MedicineScanEvent
}

