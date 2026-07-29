import SwiftUI

/// Marks every screen that is driven by demo data.
///
/// Required by the project's safety rules: any demo content must be labelled so
/// it can never be mistaken for a clinical result.
struct DemoDataBanner: View {
    var body: some View {
        // The English marker is mandated verbatim by
        // docs/DEVELOPMENT_STYLE_GUIDE.md, so it stays as-is and the Chinese
        // line is added alongside it rather than replacing it — the people
        // using this app read Chinese.
        VStack(alignment: .leading, spacing: 2) {
            Text(CompanionCopy.demoDataNotice)
                .font(.caption)
                .fontWeight(.semibold)
            Text("演示数据，不用于临床用途")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("演示数据，不用于临床用途")
    }
}

/// The app's standing reminder that SlowWalk gives reminders, not diagnoses.
struct NotADiagnosisNotice: View {
    var body: some View {
        Text("SlowWalk 提供风险提示，不做医疗诊断。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: 16) {
        DemoDataBanner()
        NotADiagnosisNotice()
    }
    .padding()
}
