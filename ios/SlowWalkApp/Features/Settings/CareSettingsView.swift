import SwiftUI

/// Skeleton for care settings.
///
/// Nothing here is persisted yet, and that is stated on screen rather than
/// implied. Real persistence waits for protected storage: `ios/README.md`
/// records that the current JSON repository has no Apple Data Protection, so
/// real health data must not be written.
struct CareSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Form {
            Section {
                DemoDataBanner()
                    .slowWalkReadableContent()
            }

            Section("称呼") {
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(environment.plan.preferredName)
                            .font(.body.weight(.semibold))
                        Text("演示内容，只读")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("当前称呼", systemImage: "person.text.rectangle")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "当前称呼，\(environment.plan.preferredName)，演示内容，只读"
                )
                .slowWalkReadableContent()

                Text("当前称呼来自演示计划，本阶段暂不可修改。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .slowWalkReadableContent()
            }

            Section("提示方式") {
                LabeledContent {
                    Text("跟随系统")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("文字大小", systemImage: "textformat.size")
                }
                .slowWalkReadableContent()

                LabeledContent {
                    Text("尚未接入")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("语音提醒", systemImage: "speaker.wave.2")
                }
                .slowWalkReadableContent()

                Text("字号目前跟随系统的“显示与文字大小”设置。语音提醒将在后续阶段接入。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .slowWalkReadableContent()
            }

            Section("紧急联系人") {
                LabeledContent {
                    Text("尚未接入")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("联系人", systemImage: "person.crop.circle.badge.exclamationmark")
                }
                .slowWalkReadableContent()

                Text("可以联系谁由您自己决定。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .slowWalkReadableContent()
            }

            Section("说明") {
                NavigationLink {
                    SafetyInformationView()
                } label: {
                    Label("安全与使用说明", systemImage: "shield.lefthalf.filled")
                }
                .accessibilityHint("查看演示数据、功能边界和数据保存说明。")
                .slowWalkReadableContent()
            }
        }
    }
}

#Preview {
    NavigationStack {
        CareSettingsView()
            .navigationTitle("关怀设置")
    }
    .environment(AppEnvironment.preview())
}
