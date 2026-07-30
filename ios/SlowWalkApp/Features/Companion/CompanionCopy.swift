import Foundation
import SlowWalkAPIContracts
import SlowWalkClientCore
import SlowWalkDomain

/// Every user-facing string for the companion flow.
///
/// Wording rules this file must keep (from the product requirements):
/// - Never blame the person. A photo that could not be read is the app's
///   limitation to state plainly, not the person's mistake.
/// - Never infantilise. No "be good", no "listen to us", no pet names.
/// - Never assume a family structure. No "ask your child" or "ask your
///   daughter"; say "someone you trust" and let the person decide who.
/// - Always say what happened, then what to do first, in that order.
/// - On a failed read, offer a recovery path. Never offer a medicine
///   conclusion, dosage, or safety verdict.
/// - Never describe a capability this build does not have. A sentence about
///   reading a photo, following a route, or reminding on arrival is a claim
///   about the world; it may only be written when the `CapabilityCatalog` in
///   force says the capability is real. Where wording depends on a capability,
///   the catalog is passed in by the caller — this type holds none of its own,
///   so the wording always describes the same build the flow is running.
///
/// DEMO DATA — NOT FOR CLINICAL USE
enum CompanionCopy {
    static let demoDataNotice = "DEMO DATA — NOT FOR CLINICAL USE"

    static func stepLabel(
        for state: CompanionFlowState,
        medicineState: MedicineAssessmentViewState
    ) -> String {
        switch state {
        case .notStarted:
            "尚未开始"
        case .preDepartureCheck:
            "开始前确认"
        case .medicineAssessment:
            medicineStepLabel(medicineState)
        case .travelling:
            "出行演示"
        case .approachingStop:
            "接近目的地"
        case .completed(let completion):
            switch completion {
            case .medicineReviewed: "已查看提示"
            case .arrivedSafely: "已安全结束"
            case .endedEarly: "已提前结束"
            }
        }
    }

    static func situation(
        for state: CompanionFlowState,
        medicineState: MedicineAssessmentViewState,
        capabilities: CapabilityCatalog
    ) -> String {
        switch state {
        case .notStarted:
            "今天的陪伴还没有开始。"
        case .preDepartureCheck:
            capabilities.detail(of: .medicineRiskAssessment)
                ?? "先完成一次设备内用药演示评估。"
        case .medicineAssessment:
            medicineSituation(medicineState)
        case .travelling:
            "出行进度由按钮模拟；当前没有读取真实位置。"
        case .approachingStop:
            "演示进度已设为接近目的地；这不是定位结果。"
        case .completed(let completion):
            switch completion {
            case .medicineReviewed:
                "这次用药提示已经查看完毕。"
            case .arrivedSafely:
                "今天的行程演示已经结束。"
            case .endedEarly:
                "这次陪伴已经结束，随时可以重新开始。"
            }
        }
    }

    static func nextStep(
        for state: CompanionFlowState,
        medicineState: MedicineAssessmentViewState
    ) -> String {
        switch state {
        case .notStarted:
            "准备好以后，点击“开始陪伴”。"
        case .preDepartureCheck:
            "点击下方按钮，评估明确标注的预设演示输入。"
        case .medicineAssessment:
            medicineNextStep(medicineState)
        case .travelling:
            "使用下方按钮模拟接近目的地。"
        case .approachingStop:
            "使用下方按钮结束本次出行演示。"
        case .completed:
            "记录已保存在本次运行的内存中。"
        }
    }

    static func reason(
        for state: CompanionFlowState,
        medicineState: MedicineAssessmentViewState
    ) -> String? {
        switch state {
        case .preDepartureCheck:
            "评估在设备内完成，不会连接远程服务。"
        case .medicineAssessment:
            switch medicineState {
            case .requiresMedicineConfirmation(let requirement):
                requirement.reason == .serverRequiresConfirmation
                    ? "来源或证据警告不能通过选择药名消除。"
                    : "只有本次解析真正给出的候选项可以被确认。"
            case .result:
                "提示来自演示规则，不替代医生诊断或处方。"
            case .failed:
                "系统不会在没有评估结果时生成用药结论。"
            case .idle, .recognizing, .assessing, .cancelled:
                nil
            }
        case .approachingStop:
            "当前阶段没有接入 CoreLocation 或自动到站提醒。"
        case .notStarted, .travelling, .completed:
            nil
        }
    }

    static let startCompanionTitle = "开始陪伴"
    static let continueCompanionTitle = "继续陪伴"
    static let beginMedicineAssessmentTitle = "评估预设演示药品"
    static let retryMedicineAssessmentTitle = "重新评估"
    static let acknowledgeCareActionTitle = "知道了，继续"
    static let continueToOutingTitle = "知道了，继续出行演示"
    static let approachStopTitle = "模拟：接近目的地"
    static let arriveSafelyTitle = "模拟：结束行程"
    static let endEarlyTitle = "先结束这次陪伴"

    private static func medicineStepLabel(
        _ state: MedicineAssessmentViewState
    ) -> String {
        switch state {
        case .idle: "等待评估"
        case .recognizing: "正在处理演示输入"
        case .assessing: "正在设备内评估"
        case .requiresMedicineConfirmation(let requirement):
            requirement.reason == .serverRequiresConfirmation
                ? "来源需要复核"
                : "请确认药名"
        case .result: "用药提示"
        case .failed: "评估未完成"
        case .cancelled: "评估已取消"
        }
    }

    private static func medicineSituation(
        _ state: MedicineAssessmentViewState
    ) -> String {
        switch state {
        case .idle:
            return "设备内评估尚未开始。"
        case .recognizing:
            return "正在处理预设的演示药品文字；没有调用相机。"
        case .assessing:
            return "正在设备内运行确定性演示规则；没有连接服务器。"
        case .requiresMedicineConfirmation(let requirement):
            let count = requirement.response?.resolution.candidates.count ?? 0
            if requirement.reason == .serverRequiresConfirmation {
                return "药名已经解析，但信息来源或证据仍需复核，当前不能继续。"
            }
            return count > 0
                ? "设备内解析给出了 \(count) 个候选药名，还不能自动确定。"
                : "这次输入不足以确定药名，系统没有生成用药结论。"
        case .result(let presentation):
            let name =
                presentation.response.resolution.selectedMedicine?
                .canonicalName ?? "演示药品"
            return "设备内评估已完成：\(name)。"
        case .failed(let failure):
            return failure.kind == .timeout
                ? "评估等待超时，没有生成用药结论。"
                : "评估没有完成，也没有生成用药结论。"
        case .cancelled:
            return "评估已经取消，没有生成用药结论。"
        }
    }

    private static func medicineNextStep(
        _ state: MedicineAssessmentViewState
    ) -> String {
        switch state {
        case .idle:
            return "返回上一步重新开始。"
        case .recognizing, .assessing:
            return "请稍等，结果会显示在这里。"
        case .requiresMedicineConfirmation(let requirement):
            if requirement.reason == .serverRequiresConfirmation {
                return "请阅读下面的来源警告；可以重新评估，但不能直接继续。"
            }
            let hasCandidates =
                requirement.response?.resolution.candidates
                .isEmpty == false
            return hasCandidates
                ? "请选择与本次演示输入相符的候选药名。"
                : "请重新评估；不要根据当前结果用药。"
        case .result:
            return "先阅读下面的提示，再继续。"
        case .failed(let failure):
            return failure.isRecoverable
                ? "可以重新评估。"
                : "请结束本次演示并查看能力说明。"
        case .cancelled:
            return "可以重新评估。"
        }
    }
}
