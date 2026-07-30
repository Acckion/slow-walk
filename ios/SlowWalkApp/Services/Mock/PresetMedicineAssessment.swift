import Foundation
import SlowWalkClientCore
import SlowWalkDomain

/// Synthetic OCR adapter used until a Vision implementation is connected.
///
/// It returns declared preset text and never claims that image bytes were
/// captured or recognized.
struct PresetMedicineTextRecognizer: MedicineTextRecognizing {
    let texts: [String]
    let confidence: Double

    func recognizeText(
        in input: OCRImageInput
    ) async throws -> [RecognizedTextObservation] {
        try Task.checkCancellation()
        return texts.map {
            RecognizedTextObservation(
                text: $0,
                confidence: confidence,
                boundingRegion: nil,
                languageCode: "en",
                observedAt: input.capturedAt
            )
        }
    }

    static let medicineDemo = PresetMedicineTextRecognizer(
        texts: ["Acetaminophen"],
        confidence: 0.99
    )
}

/// Declared input for the device-local medicine demo.
struct DemoMedicineAssessmentInput: Sendable {
    let imageInput: OCRImageInput
    let userProfile: UserHealthProfile
    let recentRecords: [MedicationRecord]

    static func make(at date: Date) -> DemoMedicineAssessmentInput {
        DemoMedicineAssessmentInput(
            imageInput: OCRImageInput(
                data: Data("preset-medicine-demo".utf8),
                orientation: .up,
                capturedAt: date
            ),
            userProfile: UserHealthProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000070")!,
                age: 70,
                allergies: [],
                diagnosedConditions: [],
                currentMedicineIngredientIDs: [],
                bodyMetrics: BodyMetrics(
                    systolicBloodPressure: 120,
                    diastolicBloodPressure: 75,
                    heartRate: 68,
                    measuredAt: date,
                    source: "synthetic_demo"
                ),
                updatedAt: date
            ),
            recentRecords: []
        )
    }
}
