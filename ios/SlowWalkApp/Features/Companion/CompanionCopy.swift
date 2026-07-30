import Foundation

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
///
/// DEMO DATA — NOT FOR CLINICAL USE
enum CompanionCopy {
    static let demoDataNotice = "DEMO DATA — NOT FOR CLINICAL USE"

    /// Short label for the current step, used in summaries and VoiceOver.
    static func stepLabel(for state: CompanionFlowState) -> String {
        switch state {
        case .notStarted:
            "尚未开始"
        case .preDepartureCheck:
            "出门前确认"
        case let .scanningMedicine(attempt):
            attempt.isAwaitingRecovery ? "需要再试一次" : "正在处理演示输入"
        case .awaitingMedicineConfirmation:
            "请确认药名"
        case .showingRiskAction:
            "用药提示"
        case .travelling:
            "出行途中"
        case .approachingStop:
            "即将到站"
        case let .completed(completion):
            switch completion {
            case .arrivedSafely: "已安全结束"
            case .endedEarly: "已提前结束"
            }
        }
    }

    /// What happened. States the situation without evaluating the person.
    static func situation(for state: CompanionFlowState) -> String {
        switch state {
        case .notStarted:
            "今天的陪伴还没有开始。"
        case .preDepartureCheck:
            "出门前，我们一起把要带的东西过一遍。"
        case let .scanningMedicine(attempt):
            if let setback = attempt.setback {
                setbackSituation(setback)
            } else if attempt.attemptNumber == 1 {
                "正在处理预设的演示药盒文字。"
            } else {
                "正在重新处理预设的演示药盒文字。"
            }
        case let .awaitingMedicineConfirmation(prompt):
            switch prompt.origin {
            case .readFromPhoto:
                "演示输入给出了几个相近的药名，还不能确定是哪一个。"
            case .chosenFromFrequentList:
                "已经打开常用药名列表。"
            }
        case let .showingRiskAction(confirmed):
            // Only a photo-based read can speak about "this box". A medicine
            // picked from a list was never read, so the wording must not
            // claim the box was identified.
            switch confirmed.origin {
            case .readFromPhoto:
                "已确认这盒是\(confirmed.candidate.displayName)。"
            case .chosenFromFrequentList:
                "已按您选择的\(confirmed.candidate.displayName)继续。"
            }
        case .travelling:
            "出行演示已经开始；当前没有记录真实路线。"
        case .approachingStop:
            "演示进度已设为接近目的地；这不是定位结果。"
        case let .completed(completion):
            switch completion {
            case .arrivedSafely:
                "今天的行程已经安全结束。"
            case .endedEarly:
                "这次陪伴已经结束，随时可以重新开始。"
            }
        }
    }

    /// What to do first. One action, stated plainly.
    static func nextStep(for state: CompanionFlowState) -> String {
        switch state {
        case .notStarted:
            "准备好以后，点击“开始陪伴”。"
        case .preDepartureCheck:
            "先确认要带的药，再出门。"
        case let .scanningMedicine(attempt):
            if attempt.setback != nil {
                "可以重新处理演示输入，也可以从演示药名里选。"
            } else {
                "预设输入正在处理，请稍等一下。"
            }
        case let .awaitingMedicineConfirmation(prompt):
            switch prompt.origin {
            case .readFromPhoto:
                "请选择本次演示要确认的药名。"
            case .chosenFromFrequentList:
                "请选出这次要用的药。"
            }
        case .showingRiskAction:
            "先看完下面的用药提示，再继续出发。"
        case .travelling:
            "使用下面的按钮模拟出行进度；本阶段不会自动提醒。"
        case .approachingStop:
            "可以先收好东西，准备下车。"
        case .completed:
            "记录已经保存，可以在守护记录里查看。"
        }
    }

    /// Why this step exists. Never a medical claim.
    static func reason(for state: CompanionFlowState) -> String? {
        switch state {
        case .preDepartureCheck:
            "出门前确认一次，路上就不用再翻找。"
        case let .scanningMedicine(attempt):
            attempt.setback != nil
                ? "药名要确认清楚，才能给出对得上的提示。"
                : nil
        case .awaitingMedicineConfirmation:
            "不同的药提示不一样，确认之后才准确。"
        case .showingRiskAction:
            "这里只做用药提示，不替代医生的诊断。"
        case .approachingStop:
            "提前一点准备，下车时不用着急。"
        case .notStarted, .travelling, .completed:
            nil
        }
    }

    private static func setbackSituation(_ setback: MedicineReadSetback) -> String {
        switch setback {
        case .textNotLegible:
            "这次演示输入没有得到清晰文字。"
        case .noMedicineNameFound:
            "这次演示输入里没有找到药名。"
        }
    }

    // MARK: - Recovery and actions

    static let retryPhotoTitle = "重新处理演示输入"
    static let chooseFromListTitle = "从演示药名里选"
    static let readAloudAgainTitle = "再说一遍"
    static let whyThisHappenedTitle = "看看原因"
    static let contactSomeoneTitle = "联系信任的人"
    static let remindLaterTitle = "稍后提醒"

    static let startCompanionTitle = "开始陪伴"
    static let continueCompanionTitle = "继续陪伴"
    static let beginMedicineReadTitle = "评估演示药品"
    static let acknowledgeCareActionTitle = "知道了，继续出发"
    static let approachStopTitle = "模拟：接近目的地"
    static let arriveSafelyTitle = "模拟：已安全到达"
    static let endEarlyTitle = "先结束这次陪伴"

    /// Why a person might contact someone, without naming a relative.
    static let contactSomeoneHint = "可以联系一位您信任的人一起看看。"
}
