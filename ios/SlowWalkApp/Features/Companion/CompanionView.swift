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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DemoDataBanner()
                stepHeader
                stepControls
                if session.canEndEarly {
                    endEarlyButton
                }
                NotADiagnosisNotice()
            }
            .slowWalkReadableContent()
            .padding()
        }
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

    // MARK: - Header

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.stepLabel)
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($accessibilityFocus, equals: .stepHeader)

            VStack(alignment: .leading, spacing: 4) {
                Text("发生了什么")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(session.situation)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("现在先做什么")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(session.nextStep)
                    .font(.body)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let reason = session.reason {
                VStack(alignment: .leading, spacing: 4) {
                    Text("为什么这样做")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(reason)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step controls

    @ViewBuilder
    private var stepControls: some View {
        switch session.state {
        case .notStarted:
            primaryButton(CompanionCopy.startCompanionTitle) {
                guard session.startCompanion() else { return }
            }

        case .preDepartureCheck:
            primaryButton(CompanionCopy.beginMedicineReadTitle) {
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
            VStack(alignment: .leading, spacing: 12) {
                CareActionPresentationSlot(confirmedMedicine: confirmed)
                primaryButton(CompanionCopy.acknowledgeCareActionTitle) {
                    session.acknowledgeCareAction()
                }
            }

        case .travelling:
            primaryButton(CompanionCopy.approachStopTitle) {
                session.approachStop()
            }

        case .approachingStop:
            primaryButton(CompanionCopy.arriveSafelyTitle) {
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
        .padding(.vertical, 12)
        .accessibilityLabel("正在读取药盒上的文字")
        .accessibilityValue("读取中")
        .accessibilityHint("请稍等，读取完成后会显示下一步。")
    }

    /// Recovery paths after a read that did not succeed.
    ///
    /// No medicine conclusion is offered here — only ways forward.
    private var recoveryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(session.recoveryOptions) { option in
                switch option {
                case .retryPhoto:
                    primaryButton(option.title) {
                        session.retryMedicineRead()
                    }
                case .chooseFromList:
                    secondaryButton(option.title) {
                        session.chooseFromFrequentList()
                    }
                case .contactSomeone:
                    unavailableContact(option)
                }
            }
        }
    }

    private func unavailableContact(_ option: CompanionRecoveryOption) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(
                cornerRadius: SlowWalkLayout.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(option.title)。\(CompanionCopy.contactSomeoneHint) 本阶段尚未接入联系功能。"
        )
    }

    private func confirmationControls(_ prompt: MedicineConfirmationPrompt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(prompt.candidates) { candidate in
                Button {
                    session.confirmMedicine(candidate)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(candidate.recognitionHint)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: SlowWalkLayout.minimumTapTarget)
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("选择 \(candidate.displayName)")
                .accessibilityHint(candidate.recognitionHint)
            }

            Text("如果都对不上，可以重新拍一次。")
                .font(.body)
                .foregroundStyle(.secondary)

            secondaryButton(CompanionCopy.retryPhotoTitle) {
                session.retakeMedicinePhoto()
            }
        }
    }

    private var completedControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("这次陪伴的记录已经保存。", systemImage: "checkmark.circle.fill")
                .font(.body)
                .accessibilityElement(children: .combine)
            primaryButton(CompanionCopy.startCompanionTitle) {
                guard session.startCompanion() else { return }
            }
        }
    }

    private var endEarlyButton: some View {
        Button {
            isShowingEndEarlyConfirmation = true
        } label: {
            Label(CompanionCopy.endEarlyTitle, systemImage: "xmark.circle")
                .font(.body)
                .frame(minHeight: SlowWalkLayout.minimumTapTarget)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
        .accessibilityHint("先显示确认选项，已经产生的记录会保留到本次运行结束。")
    }

    // MARK: - Button helpers

    private func primaryButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        SlowWalkPrimaryActionButton(
            title: title,
            accessibilityHint: nil,
            action: action
        )
    }

    private func secondaryButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SlowWalkLayout.minimumTapTarget)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
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
