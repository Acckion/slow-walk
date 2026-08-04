import SwiftUI
import SlowWalkDomain

struct SlowWalkOnboardingView: View {
    typealias DraftSubmission = @MainActor (UserProfileDraft) async throws -> Void
    typealias DemoSelection = @MainActor () async throws -> Void
    typealias Completion = @MainActor () -> Void

    private enum SubmissionKind {
        case profile
        case demo
    }

    private enum ListField {
        case conditions
        case allergies
        case medicines
    }

    private let onSubmit: DraftSubmission
    private let onUseDemoData: DemoSelection
    private let onComplete: Completion

    @State private var draft: UserProfileDraft
    @State private var flow: SlowWalkOnboardingFlowState
    @State private var conditionText = ""
    @State private var allergyText = ""
    @State private var medicineText = ""
    @State private var validationMessage: String?
    @State private var listInputMessage: String?
    @State private var failedSubmission: SubmissionKind?
    @State private var failureMessage: String?
    @State private var isSubmitting = false
    @State private var completedWithDemoData = false
    @AccessibilityFocusState private var focusedStep: SlowWalkOnboardingStep?
    @AccessibilityFocusState private var validationMessageIsFocused: Bool

    init(
        initialDraft: UserProfileDraft = UserProfileDraft(),
        initialStep: SlowWalkOnboardingStep = .welcome,
        onSubmit: @escaping DraftSubmission,
        onUseDemoData: @escaping DemoSelection,
        onComplete: @escaping Completion
    ) {
        _draft = State(initialValue: initialDraft)
        _flow = State(initialValue: SlowWalkOnboardingFlowState(step: initialStep))
        self.onSubmit = onSubmit
        self.onUseDemoData = onUseDemoData
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if failureMessage == nil {
                    progressHeader
                    stepContent
                } else {
                    submissionFailureContent
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if showsBackButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            goBack()
                        } label: {
                            Label("返回", systemImage: "chevron.backward")
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("返回上一步")
                        .disabled(isSubmitting)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onAppear {
                focusedStep = flow.step
            }
            .onChange(of: flow.step) { _, newStep in
                focusedStep = newStep
            }
            .onChange(of: draft.preferredName) {
                clearValidationMessage(for: .preferredName)
            }
            .onChange(of: draft.ageText) {
                clearValidationMessage(for: .age)
            }
        }
    }

    @ViewBuilder
    private var progressHeader: some View {
        if let position = flow.step.formPosition {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(
                    value: Double(position),
                    total: Double(flow.step.formStepCount)
                )
                Text("第 \(position) 步，共 \(flow.step.formStepCount) 步")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGroupedBackground))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("资料设置进度")
            .accessibilityValue("第 \(position) 步，共 \(flow.step.formStepCount) 步")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case .welcome:
            welcomeContent
        case .preferredName:
            preferredNameContent
        case .age:
            ageContent
        case .conditions:
            itemsContent(
                step: .conditions,
                text: $conditionText,
                items: $draft.diagnosedConditions,
                placeholder: "例如：高血压",
                sectionTitle: "医生已告知的健康情况",
                emptyText: "没有需要补充的内容时，可以直接继续。",
                field: .conditions
            )
        case .allergies:
            itemsContent(
                step: .allergies,
                text: $allergyText,
                items: $draft.allergies,
                placeholder: "例如：青霉素或花生",
                sectionTitle: "药物或食物过敏",
                emptyText: "不清楚或没有需要补充的内容时，可以直接继续。",
                field: .allergies
            )
        case .medicines:
            itemsContent(
                step: .medicines,
                text: $medicineText,
                items: $draft.currentMedicineNames,
                placeholder: "输入药盒上的名称",
                sectionTitle: "正在使用的药品名称",
                emptyText: "药名会先作为待确认信息保存，"
                    + "不会自动转换为药品成分。",
                field: .medicines
            )
        case .review:
            reviewContent
        case .complete:
            completionContent
        }
    }

    private var welcomeContent: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: SlowWalkOnboardingStep.welcome.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    Text(SlowWalkOnboardingStep.welcome.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text(
                        "用大约一分钟补充基本资料，"
                            + "让陪伴信息更符合您的情况。"
                    )
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedStep, equals: .welcome)
                .slowWalkReadableContent()
            }

            Section("接下来") {
                onboardingSummaryRow(
                    "填写称呼和年龄",
                    detail: "用于页面问候和基本信息展示。",
                    systemImage: "person.text.rectangle"
                )
                onboardingSummaryRow(
                    "补充健康与用药信息",
                    detail: "不清楚的项目可以留空，之后再完善。",
                    systemImage: "heart.text.square"
                )
                onboardingSummaryRow(
                    "确认后再保存",
                    detail: "进入主页前会提供一页完整摘要。",
                    systemImage: "checklist"
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    private var preferredNameContent: some View {
        List {
            introduction(for: .preferredName,
                detail: "这个称呼会用于页面问候。")

            Section {
                TextField("例如：王阿姨", text: $draft.preferredName)
                    .textContentType(.nickname)
                    .submitLabel(.next)
                    .onSubmit(goForward)
                    .slowWalkReadableContent()
            } header: {
                Text("称呼")
            } footer: {
                validationFooter("最多 30 个字符。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    private var ageContent: some View {
        List {
            introduction(for: .age,
                detail: "年龄用于后续资料校验和个性化展示。")

            Section {
                TextField("例如：68", text: $draft.ageText)
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .slowWalkReadableContent()
            } header: {
                Text("年龄")
            } footer: {
                validationFooter("请填写 1 到 120 之间的数字。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    private func itemsContent(
        step: SlowWalkOnboardingStep,
        text: Binding<String>,
        items: Binding<[String]>,
        placeholder: String,
        sectionTitle: String,
        emptyText: String,
        field: ListField
    ) -> some View {
        List {
            introduction(for: step, detail: introductionDetail(for: field))

            Section {
                HStack(alignment: .firstTextBaseline) {
                    TextField(placeholder, text: text)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem(text.wrappedValue, to: field)
                        }

                    Button("添加") {
                        addItem(text.wrappedValue, to: field)
                    }
                    .disabled(text.wrappedValue.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty)
                }
                .slowWalkReadableContent()
            } header: {
                Text(sectionTitle)
            } footer: {
                if let listInputMessage {
                    Text(listInputMessage)
                        .foregroundStyle(.red)
                        .accessibilityFocused($validationMessageIsFocused)
                } else {
                    Text(emptyText)
                }
            }

            if !items.wrappedValue.isEmpty {
                Section("已添加") {
                    ForEach(items.wrappedValue.indices, id: \.self) { index in
                        Text(items.wrappedValue[index])
                            .fixedSize(horizontal: false, vertical: true)
                            .slowWalkReadableContent()
                    }
                    .onDelete { offsets in
                        items.wrappedValue.remove(atOffsets: offsets)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    private var reviewContent: some View {
        List {
            introduction(for: .review,
                detail: "请核对以下内容。保存前可以返回修改。")

            Section("基本资料") {
                LabeledContent("称呼", value: draft.preferredName)
                    .slowWalkReadableContent()
                LabeledContent("年龄", value: "\(draft.ageText) 岁")
                    .slowWalkReadableContent()
            }

            Section("健康资料") {
                reviewRow("健康情况", values: draft.diagnosedConditions)
                reviewRow("过敏情况", values: draft.allergies)
                reviewRow("当前用药", values: draft.currentMedicineNames)
            }

            Section {
                Label {
                    Text(
                        "药品名称会作为待确认信息保存，"
                            + "不会自动转换为成分、剂量或用药建议。"
                    )
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .slowWalkReadableContent()
            } header: {
                Text("信息边界")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var completionContent: some View {
        List {
            Section {
                ContentUnavailableView {
                    Label(
                        completedWithDemoData ? "演示资料已就绪" : "资料已保存",
                        systemImage: "checkmark.circle"
                    )
                } description: {
                    Text(
                        completedWithDemoData
                            ? "现在可以进入慢行，体验完整的演示流程。"
                            : "现在可以进入慢行。"
                    )
                }
                .accessibilityFocused($focusedStep, equals: .complete)
                .slowWalkReadableContent()
            }

            Section("您可以继续") {
                onboardingSummaryRow(
                    "查看今天的安排",
                    detail: "首页会汇总当前状态和待办事项。",
                    systemImage: "sun.max"
                )
                onboardingSummaryRow(
                    "使用陪伴功能",
                    detail: "按需进入用药守护或出行陪伴。",
                    systemImage: "figure.walk"
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    private var submissionFailureContent: some View {
        List {
            Section {
                ContentUnavailableView {
                    Label("暂时无法保存", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(failureMessage ?? "请稍后重试。")
                }
                .slowWalkReadableContent()
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 12) {
            if failureMessage != nil {
                primaryButton("重试保存", systemImage: "arrow.clockwise") {
                    retrySubmission()
                }

                Button("返回检查资料") {
                    let returnStep: SlowWalkOnboardingStep
                    switch failedSubmission {
                    case .demo:
                        returnStep = .welcome
                    case .profile, .none:
                        returnStep = .review
                    }
                    failureMessage = nil
                    failedSubmission = nil
                    flow.step = returnStep
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: SlowWalkLayout.minimumTapTarget)
            } else {
                switch flow.step {
                case .welcome:
                    primaryButton("开始设置", systemImage: "arrow.forward") {
                        goForward()
                    }

                    Button {
                        beginSubmission(.demo)
                    } label: {
                        Label("使用演示资料", systemImage: "play.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(minHeight: SlowWalkLayout.minimumTapTarget)
                    .disabled(isSubmitting)
                case .review:
                    primaryButton("保存并继续", systemImage: "checkmark") {
                        beginSubmission(.profile)
                    }
                case .complete:
                    primaryButton("进入慢行", systemImage: "arrow.forward") {
                        onComplete()
                    }
                case .preferredName, .age, .conditions, .allergies, .medicines:
                    primaryButton("继续", systemImage: "arrow.forward") {
                        goForward()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func primaryButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isSubmitting {
                HStack {
                    ProgressView()
                    Text("正在保存")
                }
                .frame(maxWidth: .infinity)
            } else {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(minHeight: SlowWalkLayout.minimumTapTarget)
        .disabled(isSubmitting)
        .accessibilityLabel(isSubmitting ? "正在保存资料" : title)
    }

    private func introduction(
        for step: SlowWalkOnboardingStep,
        detail: String
    ) -> some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.title)
                        .font(.title2.bold())
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: step.systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focusedStep, equals: step)
            .slowWalkReadableContent()
        }
    }

    private func validationFooter(_ fallback: String) -> some View {
        Group {
            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
                    .accessibilityFocused($validationMessageIsFocused)
            } else {
                Text(fallback)
            }
        }
    }

    private func reviewRow(_ title: String, values: [String]) -> some View {
        LabeledContent {
            Text(values.isEmpty ? "未填写" : values.joined(separator: "、"))
                .foregroundStyle(values.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .slowWalkReadableContent()
    }

    private func onboardingSummaryRow(
        _ title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .slowWalkReadableContent()
    }

    private var navigationTitle: String {
        failureMessage == nil ? flow.step.title : "保存资料"
    }

    private var showsBackButton: Bool {
        failureMessage == nil
            && flow.step != .welcome
            && flow.step != .complete
    }

    private func introductionDetail(for field: ListField) -> String {
        switch field {
        case .conditions:
            "只填写医生已经告知的情况，不确定时可以留空。"
        case .allergies:
            "可填写已知的药物或食物过敏，不确定时可以留空。"
        case .medicines:
            "请照着药盒填写名称，不需要填写剂量或自行判断成分。"
        }
    }

    private func goForward() {
        if let message = SlowWalkOnboardingInputRules.validationMessage(
            for: flow.step,
            draft: draft
        ) {
            validationMessage = message
            validationMessageIsFocused = true
            return
        }

        validationMessage = nil
        listInputMessage = nil
        flow.advance()
    }

    private func goBack() {
        validationMessage = nil
        listInputMessage = nil
        flow.goBack()
    }

    private func clearValidationMessage(for step: SlowWalkOnboardingStep) {
        guard flow.step == step else { return }
        validationMessage = nil
    }

    private func addItem(_ rawValue: String, to field: ListField) {
        let currentItems: [String]
        switch field {
        case .conditions:
            currentItems = draft.diagnosedConditions
        case .allergies:
            currentItems = draft.allergies
        case .medicines:
            currentItems = draft.currentMedicineNames
        }

        switch SlowWalkOnboardingInputRules.appending(rawValue, to: currentItems) {
        case let .success(items):
            listInputMessage = nil
            switch field {
            case .conditions:
                draft.diagnosedConditions = items
                conditionText = ""
            case .allergies:
                draft.allergies = items
                allergyText = ""
            case .medicines:
                draft.currentMedicineNames = items
                medicineText = ""
            }
        case let .failure(issue):
            listInputMessage = issue.message
            validationMessageIsFocused = true
        }
    }

    private func beginSubmission(_ kind: SubmissionKind) {
        isSubmitting = true
        failedSubmission = kind
        failureMessage = nil

        Task { @MainActor in
            do {
                switch kind {
                case .profile:
                    try await onSubmit(draft)
                    completedWithDemoData = false
                case .demo:
                    try await onUseDemoData()
                    completedWithDemoData = true
                }
                isSubmitting = false
                failedSubmission = nil
                flow.step = .complete
            } catch let issue as UserProfileValidationIssue {
                isSubmitting = false
                failedSubmission = nil
                let presentation = SlowWalkOnboardingInputRules.presentation(for: issue)
                flow.step = presentation.step
                validationMessage = presentation.message
                validationMessageIsFocused = true
            } catch {
                isSubmitting = false
                failureMessage = "资料没有保存成功。请检查当前设备状态后重试，"
                    + "已经填写的内容会保留在此页面。"
            }
        }
    }

    private func retrySubmission() {
        guard let failedSubmission else { return }
        beginSubmission(failedSubmission)
    }
}

#Preview("欢迎") {
    SlowWalkOnboardingView(
        onSubmit: { _ in },
        onUseDemoData: {},
        onComplete: {}
    )
}

#Preview("确认资料 - 深色 AX5") {
    SlowWalkOnboardingView(
        initialDraft: UserProfileDraft(
            preferredName: "王阿姨",
            ageText: "68",
            allergies: ["青霉素"],
            diagnosedConditions: ["高血压"],
            currentMedicineNames: ["药盒上的示例名称"]
        ),
        initialStep: .review,
        onSubmit: { _ in },
        onUseDemoData: {},
        onComplete: {}
    )
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
