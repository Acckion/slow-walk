import Foundation

/// A medicine to be taken as part of today's plan.
///
/// DEMO DATA — NOT FOR CLINICAL USE. No dosage is modelled on purpose: this
/// shell must not present anything that could be read as a prescription.
struct TodayMedicineItem: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    /// A time of day in words, e.g. "早饭后". Not a schedule engine.
    let timeOfDayDescription: String
    let isTakenToday: Bool
}

/// A hospital visit or an outing planned for today.
///
/// DEMO DATA — NOT FOR CLINICAL USE.
struct TodayOutingItem: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let timeDescription: String
    let placeDescription: String
}

/// Everything Today needs to answer "what needs doing now".
///
/// DEMO DATA — NOT FOR CLINICAL USE.
struct TodayPlan: Equatable, Hashable {
    /// How the person prefers to be addressed. Configurable in Settings; the
    /// app never invents a nickname or a family role.
    let preferredName: String
    let medicines: [TodayMedicineItem]
    let outing: TodayOutingItem?

    var pendingMedicines: [TodayMedicineItem] {
        medicines.filter { !$0.isTakenToday }
    }

    var allMedicinesTaken: Bool {
        !medicines.isEmpty && pendingMedicines.isEmpty
    }

    /// The single most important thing today, phrased as an outcome.
    var mostImportantThing: String {
        if let outing {
            "今天要去\(outing.placeDescription)，出门前先确认要带的药。"
        } else if let next = pendingMedicines.first {
            "今天还有一次用药：\(next.displayName)，\(next.timeOfDayDescription)。"
        } else if allMedicinesTaken {
            "今天的用药都已经完成了。"
        } else {
            "今天没有安排，随时可以开始一次陪伴。"
        }
    }
}

extension TodayPlan {
    /// The plan used by the demo walkthrough.
    ///
    /// DEMO DATA — NOT FOR CLINICAL USE.
    static let demo = TodayPlan(
        preferredName: "王阿姨",
        medicines: [
            TodayMedicineItem(
                id: "demo-medicine-morning",
                displayName: "降压药",
                timeOfDayDescription: "早饭后",
                isTakenToday: true
            ),
            TodayMedicineItem(
                id: "demo-medicine-evening",
                displayName: "降糖药",
                timeOfDayDescription: "晚饭后",
                isTakenToday: false
            ),
        ],
        outing: TodayOutingItem(
            id: "demo-outing-followup",
            title: "复诊",
            timeDescription: "下午 2:30",
            placeDescription: "市第一医院"
        )
    )
}

extension MedicineCandidate {
    /// Candidates offered for confirmation in the demo flow.
    ///
    /// DEMO DATA — NOT FOR CLINICAL USE. Hints describe packaging only, never
    /// an effect or a dosage.
    static let demoCandidates: [MedicineCandidate] = [
        MedicineCandidate(
            id: "demo-candidate-a",
            displayName: "二甲双胍片",
            recognitionHint: "白色药盒，蓝色字"
        ),
        MedicineCandidate(
            id: "demo-candidate-b",
            displayName: "格列美脲片",
            recognitionHint: "白色药盒，绿色字"
        ),
    ]

    /// The person's frequently used medicines, offered as a recovery path when
    /// a photo cannot be read.
    ///
    /// DEMO DATA — NOT FOR CLINICAL USE.
    static let demoFrequentlyUsed: [MedicineCandidate] = [
        MedicineCandidate(
            id: "demo-frequent-a",
            displayName: "二甲双胍片",
            recognitionHint: "常用"
        ),
        MedicineCandidate(
            id: "demo-frequent-b",
            displayName: "降压药",
            recognitionHint: "常用"
        ),
    ]
}
