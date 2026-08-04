import SlowWalkDomain
import Testing

@testable import SlowWalkApp

@MainActor
struct SlowWalkOnboardingFlowStateTests {
    @Test func flowVisitsEveryScreenInOrder() {
        var state = SlowWalkOnboardingFlowState()
        var visited = [state.step]

        for _ in 1..<SlowWalkOnboardingStep.allCases.count {
            state.advance()
            visited.append(state.step)
        }

        #expect(visited == SlowWalkOnboardingStep.allCases)
        state.advance()
        #expect(state.step == .complete)
    }

    @Test func backNavigationStopsAtWelcome() {
        var state = SlowWalkOnboardingFlowState(step: .age)
        state.goBack()
        #expect(state.step == .preferredName)
        state.goBack()
        #expect(state.step == .welcome)
        state.goBack()
        #expect(state.step == .welcome)
    }

    @Test func progressCoversOnlyEditableStepsAndReview() {
        #expect(SlowWalkOnboardingStep.welcome.formPosition == nil)
        #expect(SlowWalkOnboardingStep.preferredName.formPosition == 1)
        #expect(SlowWalkOnboardingStep.review.formPosition == 6)
        #expect(SlowWalkOnboardingStep.complete.formPosition == nil)
    }

    @Test func requiredFieldsUseDomainLimits() {
        var draft = UserProfileDraft()
        #expect(
            SlowWalkOnboardingInputRules.validationMessage(
                for: .preferredName,
                draft: draft
            ) != nil
        )

        draft.preferredName = "王阿姨"
        draft.ageText = "abc"
        #expect(
            SlowWalkOnboardingInputRules.validationMessage(
                for: .preferredName,
                draft: draft
            ) == nil
        )
        #expect(
            SlowWalkOnboardingInputRules.validationMessage(
                for: .age,
                draft: draft
            ) == "请填写数字年龄。"
        )

        draft.ageText = "121"
        #expect(
            SlowWalkOnboardingInputRules.validationMessage(
                for: .age,
                draft: draft
            ) == "年龄需在 1 到 120 岁之间。"
        )

        draft.ageText = "68"
        #expect(
            SlowWalkOnboardingInputRules.validationMessage(
                for: .age,
                draft: draft
            ) == nil
        )
    }

    @Test func itemEntryTrimsAndRejectsDuplicates() throws {
        let first = try SlowWalkOnboardingInputRules
            .appending("  青霉素  ", to: [])
            .get()
        #expect(first == ["青霉素"])

        let duplicate = SlowWalkOnboardingInputRules.appending(
            "青霉素",
            to: first
        )
        #expect(duplicate == .failure(.duplicate))
    }

    @Test func itemEntryEnforcesDomainCountAndLengthLimits() {
        let longValue = String(
            repeating: "a",
            count: UserProfileDraftValidator.maximumItemLength + 1
        )
        #expect(
            SlowWalkOnboardingInputRules.appending(longValue, to: [])
                == .failure(.tooLong)
        )

        let fullGroup = (0..<UserProfileDraftValidator.maximumItemsPerGroup)
            .map(String.init)
        #expect(
            SlowWalkOnboardingInputRules.appending("下一项", to: fullGroup)
                == .failure(.tooMany)
        )
    }

    @Test func domainValidationIssuesReturnUserFacingStep() {
        let age = SlowWalkOnboardingInputRules.presentation(for: .ageOutOfRange)
        #expect(age.step == .age)
        #expect(age.message.contains("1 到 120"))

        let medicine = SlowWalkOnboardingInputRules.presentation(
            for: .tooManyCurrentMedicineNames
        )
        #expect(medicine.step == .medicines)
        #expect(medicine.message.contains("30"))
    }
}
