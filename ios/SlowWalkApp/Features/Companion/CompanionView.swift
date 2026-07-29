import SwiftUI

/// Holds one continuous companion session from start to finish.
///
/// Every step shows the same three things in the same order: what happened,
/// what to do first, and — when it helps — why. The step-specific controls
/// follow underneath.
struct CompanionView: View {
    private enum AccessibilityFocus: Hashable {
        case stepHeader
    }

    @Environment(AppEnvironment.self) private var environment
    @AccessibilityFocusState private var accessibilityFocus: AccessibilityFocus?
    @State private var isShowingEndEarlyConfirmation = false

    private var session: CompanionSessionModel { environment.companion }

    var body: some View {
        List {
            Section {
                DemoDataBanner()
                    .slowWalkReadableContent()
            }

            Section {
                stepSummaryRow(
                    title: "发生了什么",
                    value: session.situation,
                    systemImage: "info.circle"
                )
                stepSummaryRow(
                    title: "现在先做什么",
                    value: session.nextStep,
                    systemImage: "arrow.forward.circle",
                    isEmphasized: true
                )
                if let reason = session.reason {
                    stepSummaryRow(
                        title: "为什么这样做",
                        value: reason,
                        systemImage: "questionmark.circle"
                    )
                }
            } header: {
                Text(session.stepLabel)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(
                        $accessibilityFocus,
                        equals: .stepHeader
                    )
            }

            Section("当前操作") {
                stepControls
            }

            if session.canEndEarly {
                Section {
                    endEarlyButton
                }
            }

            Section {
                NotADiagnosisNotice()
                    .slowWalkReadableContent()
            }
        }
        .listStyle(.insetGrouped)
        .onChange(of: session.state) { _, _ in
            // Resetting first ensures VoiceOver announces each new step even
            // though the same header view remains on screen.
            accessibilityFocus = nil
            Task { @MainActor in
                await Task.yield()
                accessibilityFocus = .stepHeader
            }
        }
        .alert(
            "结束这次陪伴？",
            isPresented: $isShowingEndEarlyConfirmation
        ) {
            Button("继续陪伴", role: .cancel) {}
            Button(CompanionCopy.endEarlyTitle, role: .destructive) {
                session.endEarly()
            }
        } message: {
            Text("已经产生的陪伴记录会保留到本次运行结束。")
        }
    }

    private func stepSummaryRow(
        title: String,
        value: String,
        systemImage: String,
        isEmphasized: Bool = false
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.body)
                    .fontWeight(isEmphasized ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .frame(minHeight: SlowWalkLayout.minimumTapTarget)
        .slowWalkReadableContent()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，\(value)")
    }

    // MARK: - Step controls

    @ViewBuilder
    private var stepControls: some View {
        switch session.state {
        case .notStarted:
            primaryActionButton(
                CompanionCopy.startCompanionTitle,
                systemImage: "figure.walk"
            ) {
                guard session.startCompanion() else { return }
            }

        case .preDepartureCheck:
            primaryActionButton(
                CompanionCopy.beginMedicineReadTitle,
                systemImage: "text.viewfinder"
            ) {
                session.beginMedicineRead()
            }

        case let .scanningMedicine(attempt):
            if attempt.isAwaitingRecovery {
                recoveryControls
            } else {
                readingIndicator
            }

        case let .awaitingMedicineConfirmation(prompt):
            confirmationControls(prompt)

        case let .showingRiskAction(confirmed):
            CareActionPresentationSlot(confirmedMedicine: confirmed)
                .slowWalkReadableContent()
            primaryActionButton(
                CompanionCopy.acknowledgeCareActionTitle,
                systemImage: "checkmark.circle"
            ) {
                session.acknowledgeCareAction()
            }

        case .travelling:
            primaryActionButton(
                CompanionCopy.approachStopTitle,
                systemImage: "bus"
            ) {
                session.approachStop()
            }

        case .approachingStop:
            primaryActionButton(
                CompanionCopy.arriveSafelyTitle,
                systemImage: "mappin.and.ellipse"
            ) {
                session.arriveSafely()
            }

        case .completed:
            completedControls
        }
    }

    private var readingIndicator: some View {
        ProgressView {
            Text("正在读取药盒上的文字，请稍等")
                .font(.body)
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: SlowWalkLayout.minimumTapTarget)
        .slowWalkReadableContent()
        .accessibilityLabel("正在读取药盒上的文字")
        .accessibilityValue("读取中")
        .accessibilityHint("请稍等，读取完成后会显示下一步。")
    }

    /// Recovery paths after a read that did not succeed.
    ///
    /// No medicine conclusion is offered here — only ways forward.
    @ViewBuilder
    private var recoveryControls: some View {
        ForEach(session.recoveryOptions) { option in
            switch option {
            case .retryPhoto:
                primaryActionButton(option.title, systemImage: "camera") {
                    session.retryMedicineRead()
                }
            case .chooseFromList:
                secondaryActionButton(option.title, systemImage: "list.bullet") {
                    session.chooseFromFrequentList()
                }
            case .contactSomeone:
                unavailableContact(option)
            }
        }
    }

    private func unavailableContact(_ option: CompanionRecoveryOption) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.headline)
                Text(CompanionCopy.contactSomeoneHint)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("本阶段尚未接入联系功能。")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        } icon: {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: SlowWalkLayout.minimumTapTarget)
        .slowWalkReadableContent()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(option.title)。\(CompanionCopy.contactSomeoneHint) 本阶段尚未接入联系功能。"
        )
    }

    @ViewBuilder
    private func confirmationControls(_ prompt: MedicineConfirmationPrompt) -> some View {
        ForEach(prompt.candidates) { candidate in
            Button {
                session.confirmMedicine(candidate)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(candidate.recognitionHint)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "pills")
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: SlowWalkLayout.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("选择 \(candidate.displayName)")
            .accessibilityHint(candidate.recognitionHint)
            .slowWalkReadableContent()
        }

        Text("如果都对不上，可以重新拍一次。")
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .slowWalkReadableContent()

        secondaryActionButton(
            CompanionCopy.retryPhotoTitle,
            systemImage: "camera"
        ) {
            session.retakeMedicinePhoto()
        }
    }

    @ViewBuilder
    private var completedControls: some View {
        Label("这次陪伴的记录已经保存。", systemImage: "checkmark.circle.fill")
            .font(.body)
            .frame(minHeight: SlowWalkLayout.minimumTapTarget)
            .accessibilityElement(children: .combine)
            .slowWalkReadableContent()
        primaryActionButton(
            CompanionCopy.startCompanionTitle,
            systemImage: "arrow.clockwise"
        ) {
            guard session.startCompanion() else { return }
        }
    }

    private var endEarlyButton: some View {
        Button(role: .destructive) {
            isShowingEndEarlyConfirmation = true
        } label: {
            Label(CompanionCopy.endEarlyTitle, systemImage: "xmark.circle")
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: SlowWalkLayout.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .slowWalkReadableContent()
        .accessibilityHint("先显示确认选项，已经产生的记录会保留到本次运行结束。")
    }

    private func primaryActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .slowWalkReadableContent()
        .accessibilityLabel(title)
    }

    private func secondaryActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .slowWalkReadableContent()
        .accessibilityLabel(title)
    }
}

#Preview {
    NavigationStack {
        CompanionView()
            .navigationTitle("陪伴")
    }
    .environment(AppEnvironment.preview())
}
