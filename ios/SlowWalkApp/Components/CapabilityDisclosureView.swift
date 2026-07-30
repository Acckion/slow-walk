import SwiftUI

/// A concise, visible boundary between the demo and connected Apple features.
struct CapabilityDisclosureView: View {
    var body: some View {
        Label {
            Text("药盒文字使用预设演示输入；出行进度由按钮模拟。尚未接入相机识别、真实定位或自动到站提醒。")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CapabilityDisclosureView()
        .padding()
}
