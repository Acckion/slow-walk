import SwiftUI

/// Marks every screen that is driven by demo data.
///
/// Required by the project's safety rules: any demo content must be labelled so
/// it can never be mistaken for a clinical result.
struct DemoDataBanner: View {
    var body: some View {
        // The English marker is mandated verbatim by the development guide.
        SlowWalkNotice(
            title: CompanionCopy.demoDataNotice,
            message: "演示数据，不用于临床用途",
            systemImage: "exclamationmark.triangle.fill",
            accessibilityLabel: "演示数据，不用于临床用途。"
        )
    }
}

/// The app's standing reminder that SlowWalk gives reminders, not diagnoses.
struct NotADiagnosisNotice: View {
    var body: some View {
        SlowWalkNotice(
            title: "使用说明",
            message: "SlowWalk 提供风险提示，不做医疗诊断。",
            systemImage: "shield.lefthalf.filled"
        )
    }
}

#Preview("Light") {
    VStack(spacing: 16) {
        DemoDataBanner()
        NotADiagnosisNotice()
    }
    .padding()
}

#Preview("Dark AX5") {
    VStack(spacing: 16) {
        DemoDataBanner()
        NotADiagnosisNotice()
    }
    .padding()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
