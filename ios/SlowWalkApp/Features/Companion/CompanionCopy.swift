import Foundation
import SlowWalkClientCore

/// Non-clinical navigation copy for the companion flow.
///
/// Medical findings and recommended actions are deliberately absent. They are
/// rendered only by SlowWalkPresentation from the canonical action card.
enum CompanionCopy {
    static let demoDataNotice = "DEMO DATA — NOT FOR CLINICAL USE"

    static func stepLabel(for state: CompanionFlowState) -> String {
        switch state {
        case .notStarted:
            "尚未开始"
        case .preDepartureCheck:
            "出门前确认"
        case let .scanningMedicine(attempt):
            attempt.isAwaitingRecovery ? "需要再试一次" : "正在模拟识别"
        case .awaitingMedicineConfirmation:
            "请确认药名"
        case let .awaitingMedicineAssessment(gate):
            assessmentStepLabel(gate.viewState)
        case .travelling:
            "出行途中"
        case .approachingStop:
            "即将到站"
        case let .completed(completion):
            switch completion {
            case .arrivedSafely:
                "已安全结束"
            case .medicineReviewCompleted:
                "用药陪伴已完成"
            case .endedEarly:
                "已提前结束"
            }
        }
    }

    static func situation(
        for state: CompanionFlowState,
        capabilities _: CapabilityCatalog
    ) -> String {
        switch state {
        case .notStarted:
            "今天的陪伴还没有开始。"
        case .preDepartureCheck:
            "出门前，我们一起把要带的东西过一遍。"
        case let .scanningMedicine(attempt):
            if let setback = attempt.setback {
                setbackSituation(setback)
            } else if attempt.attemptNumber == 1 {
                "正在按演示脚本模拟识别药名，本阶段不读取照片。"
            } else {
                "正在重新模拟识别药名，本阶段不读取照片。"
            }
        case let .awaitingMedicineConfirmation(prompt):
            switch prompt.origin {
            case .readFromPhoto:
                "演示脚本给出了几个相近的药名，还不能确定是哪一个。"
            case .chosenFromFrequentList:
                "已经打开常用药名列表。"
            }
        case let .awaitingMedicineAssessment(gate):
            assessmentSituation(gate)
        case .travelling:
            "出行步骤已经开始。本阶段使用演示位置，不记录真实路线。"
        case .approachingStop:
            "这是演示中的“即将到站”步骤，由手动操作触发。"
        case let .completed(completion):
            switch completion {
            case .arrivedSafely:
                "今天的行程已经结束。"
            case .medicineReviewCompleted:
                "这次用药陪伴已经结束。"
            case .endedEarly:
                "这次陪伴已经结束，随时可以重新开始。"
            }
        }
    }

    static func nextStep(for state: CompanionFlowState) -> String {
        switch state {
        case .notStarted:
            "准备好以后，点击“开始陪伴”。"
        case .preDepartureCheck:
            "先确认要带的药，再出门。"
        case let .scanningMedicine(attempt):
            attempt.setback == nil
                ? "请稍等一下。"
                : "可以重新试一次，也可以从常用药名里选。"
        case let .awaitingMedicineConfirmation(prompt):
            switch prompt.origin {
            case .readFromPhoto:
                "请看一下药盒，选出对得上的那一个。"
            case .chosenFromFrequentList:
                "请选出这次要用的药。"
            }
        case let .awaitingMedicineAssessment(gate):
            assessmentNextStep(gate.viewState)
        case .travelling:
            "本阶段不会自动提醒到站，需要手动进入下一步。"
        case .approachingStop:
            "可以先收好东西，准备下车。"
        case .completed:
            "记录已经保存在本次运行中，可以在守护记录里查看。"
        }
    }

    static func reason(for state: CompanionFlowState) -> String? {
        switch state {
        case .preDepartureCheck:
            "出门前确认一次，路上就不用再翻找。"
        case let .scanningMedicine(attempt):
            attempt.setback == nil
                ? nil
                : "药名要确认清楚，才能显示对应的提示。"
        case .awaitingMedicineConfirmation:
            "不同的药提示不一样，确认之后才准确。"
        case .awaitingMedicineAssessment:
            "页面内容直接来自设备内评估结果，不根据药名自行推断。"
        case .approachingStop:
            "提前一点准备，下车时不用着急。"
        case .notStarted, .travelling, .completed:
            nil
        }
    }

    private static func assessmentStepLabel(
        _ state: MedicineAssessmentViewState
    ) -> String {
        switch state {
        case .idle, .recognizing, .assessing:
            "正在评估"
        case .requiresMedicineConfirmation:
            "请确认评估信息"
        case .result:
            "用药提示"
        case .failed, .cancelled:
            "评估未完成"
        }
    }

    private static func assessmentSituation(
        _ gate: MedicineAssessmentGate
    ) -> String {
        let name = gate.confirmed.candidate.displayName
        return switch gate.viewState {
        case .idle, .recognizing, .assessing:
            "已确认药名：\(name)。正在设备内生成评估结果。"
        case .requiresMedicineConfirmation:
            "设备内评估还需要确认药品身份。"
        case .result:
            "设备内评估已经返回，下面显示正式的用药提示。"
        case .failed:
            "这次设备内评估没有完成，页面不会生成用药结论。"
        case .cancelled:
            "这次设备内评估已取消，页面不会生成用药结论。"
        }
    }

    private static func assessmentNextStep(
        _ state: MedicineAssessmentViewState
    ) -> String {
        switch state {
        case .idle, .recognizing, .assessing:
            "请等待评估完成。"
        case .requiresMedicineConfirmation:
            "请从本次评估提供的候选药品中确认，或者重新读取。"
        case .result:
            "请查看下面的提示，确认后再继续。"
        case let .failed(failure):
            failure.isRecoverable
                ? "可以重试评估，或者重新选择药名。"
                : "可以重新选择药名，或者先结束这次陪伴。"
        case .cancelled:
            "可以重试评估，或者重新选择药名。"
        }
    }

    private static func setbackSituation(_ setback: MedicineReadSetback) -> String {
        switch setback {
        case .textNotLegible:
            "演示脚本这次没有给出可用的药名文字。"
        case .noMedicineNameFound:
            "演示脚本这次没有给出药名。"
        }
    }

    static let retryPhotoTitle = "重新试一次"
    static let chooseFromListTitle = "从常用药名里选"
    static let readAloudAgainTitle = "再说一遍"
    static let whyThisHappenedTitle = "看看原因"
    static let contactSomeoneTitle = "联系信任的人"
    static let remindLaterTitle = "稍后提醒"

    static let startCompanionTitle = "开始陪伴"
    static let continueCompanionTitle = "继续陪伴"
    static let beginMedicineReadTitle = "确认要带的药"
    static let reconsiderMedicineTitle = "重新选择药名"
    static let approachStopTitle = "模拟：即将到站"
    static let arriveSafelyTitle = "已安全到达"
    static let endEarlyTitle = "先结束这次陪伴"

    static let contactSomeoneHint = "可以联系一位您信任的人一起看看。"
}
