import SwiftUI

/// Factual product boundaries presented in one place without adding medical advice.
struct SafetyInformationView: View {
    var body: some View {
        List {
            Section {
                DemoDataBanner()
                    .slowWalkReadableContent()
            }

            Section {
                SafetyInformationRow(
                    title: "风险提示，不是诊断",
                    message: "SlowWalk 提供风险提示，不做医疗诊断。",
                    systemImage: "shield.lefthalf.filled"
                )
                .slowWalkReadableContent()
            } header: {
                sectionHeader("使用边界")
            }

            Section {
                SafetyInformationRow(
                    title: "仅保存在本次运行中",
                    message: "本阶段的守护记录只保存在内存中；重新启动后不会保留。",
                    systemImage: "internaldrive"
                )
                .slowWalkReadableContent()
            } header: {
                sectionHeader("数据保存")
            }

            Section {
                SafetyInformationRow(
                    title: "语音提醒",
                    message: "尚未接入。",
                    systemImage: "speaker.wave.2"
                )
                .slowWalkReadableContent()

                SafetyInformationRow(
                    title: "紧急联系人",
                    message: "尚未接入。可以联系谁由您自己决定。",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
                .slowWalkReadableContent()
            } header: {
                sectionHeader("尚未接入")
            }

            Section {
                SafetyInformationRow(
                    title: "跟随系统设置",
                    message: "文字大小、粗体文本和界面显示会跟随设备的系统辅助功能设置。",
                    systemImage: "accessibility"
                )
                .slowWalkReadableContent()
            } header: {
                sectionHeader("显示与辅助功能")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("安全与使用说明")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SafetyInformationRow: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        Label {
            text
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
        .accessibilityElement(children: .combine)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light") {
    NavigationStack {
        SafetyInformationView()
    }
}

#Preview("Dark AX5") {
    NavigationStack {
        SafetyInformationView()
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
