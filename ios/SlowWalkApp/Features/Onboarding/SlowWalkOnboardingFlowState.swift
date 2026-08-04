import Foundation
import SlowWalkDomain

enum SlowWalkOnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case preferredName
    case age
    case conditions
    case allergies
    case medicines
    case review
    case complete

    private static let formSteps: [Self] = [
        .preferredName,
        .age,
        .conditions,
        .allergies,
        .medicines,
        .review,
    ]

    var formPosition: Int? {
        Self.formSteps.firstIndex(of: self).map { $0 + 1 }
    }

    var formStepCount: Int {
        Self.formSteps.count
    }

    var title: String {
        switch self {
        case .welcome: "欢迎使用慢行"
        case .preferredName: "怎么称呼您？"
        case .age: "您的年龄"
        case .conditions: "健康情况"
        case .allergies: "过敏情况"
        case .medicines: "当前用药"
        case .review: "确认资料"
        case .complete: "设置完成"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "figure.walk"
        case .preferredName: "person.text.rectangle"
        case .age: "calendar"
        case .conditions: "heart.text.square"
        case .allergies: "allergens"
        case .medicines: "pills"
        case .review: "checklist"
        case .complete: "checkmark.circle"
        }
    }
}

struct SlowWalkOnboardingFlowState: Equatable {
    var step: SlowWalkOnboardingStep

    init(step: SlowWalkOnboardingStep = .welcome) {
        self.step = step
    }

    mutating func advance() {
        guard let next = SlowWalkOnboardingStep(rawValue: step.rawValue + 1) else {
            return
        }
        step = next
    }

    mutating func goBack() {
        guard let previous = SlowWalkOnboardingStep(rawValue: step.rawValue - 1) else {
            return
        }
        step = previous
    }
}

enum SlowWalkOnboardingItemIssue: Error, Equatable {
    case empty
    case duplicate
    case tooLong
    case tooMany

    var message: String {
        switch self {
        case .empty:
            "请先输入内容。"
        case .duplicate:
            "这项内容已经添加。"
        case .tooLong:
            "每项最多可填写 80 个字符。"
        case .tooMany:
            "每组最多可添加 30 项。"
        }
    }
}

enum SlowWalkOnboardingInputRules {
    static func validationMessage(
        for step: SlowWalkOnboardingStep,
        draft: UserProfileDraft
    ) -> String? {
        switch step {
        case .preferredName:
            let name = clean(draft.preferredName)
            if name.isEmpty {
                return "请填写希望我们使用的称呼。"
            }
            if name.count > UserProfileDraftValidator.maximumPreferredNameLength {
                return "称呼最多可填写 30 个字符。"
            }
        case .age:
            let ageText = clean(draft.ageText)
            guard let age = Int(ageText) else {
                return "请填写数字年龄。"
            }
            if !UserProfileDraftValidator.validAgeRange.contains(age) {
                return "年龄需在 1 到 120 岁之间。"
            }
        case .welcome, .conditions, .allergies, .medicines, .review, .complete:
            break
        }
        return nil
    }

    static func appending(
        _ rawValue: String,
        to items: [String]
    ) -> Result<[String], SlowWalkOnboardingItemIssue> {
        let value = clean(rawValue)
        guard !value.isEmpty else {
            return .failure(.empty)
        }
        guard value.count <= UserProfileDraftValidator.maximumItemLength else {
            return .failure(.tooLong)
        }
        guard items.count < UserProfileDraftValidator.maximumItemsPerGroup else {
            return .failure(.tooMany)
        }

        let comparisonKey = value.lowercased()
        let containsValue = items.contains {
            clean($0).lowercased() == comparisonKey
        }
        guard !containsValue else {
            return .failure(.duplicate)
        }

        return .success(items + [value])
    }

    static func presentation(
        for issue: UserProfileValidationIssue
    ) -> (step: SlowWalkOnboardingStep, message: String) {
        switch issue {
        case .emptyPreferredName:
            (.preferredName, "请填写希望我们使用的称呼。")
        case .preferredNameTooLong:
            (.preferredName, "称呼最多可填写 30 个字符。")
        case .ageNotANumber:
            (.age, "请填写数字年龄。")
        case .ageOutOfRange:
            (.age, "年龄需在 1 到 120 岁之间。")
        case .tooManyAllergies:
            (.allergies, "过敏情况最多可添加 30 项。")
        case .allergyTooLong:
            (.allergies, "每项过敏情况最多可填写 80 个字符。")
        case .tooManyDiagnosedConditions:
            (.conditions, "健康情况最多可添加 30 项。")
        case .diagnosedConditionTooLong:
            (.conditions, "每项健康情况最多可填写 80 个字符。")
        case .tooManyCurrentMedicineNames:
            (.medicines, "当前用药最多可添加 30 项。")
        case .currentMedicineNameTooLong:
            (.medicines, "每个药名最多可填写 80 个字符。")
        @unknown default:
            (.review, "请检查填写的资料后再试。")
        }
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
