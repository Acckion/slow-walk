import SwiftUI

/// A concise, visible boundary between the demo and connected Apple features.
struct CapabilityDisclosureView: View {
    let catalog: CapabilityCatalog

    var body: some View {
        Label {
            Text(disclosure)
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

    private var disclosure: String {
        let recognition = catalog.status(of: .medicineRecognition)
        let assessment = catalog.status(of: .medicineRiskAssessment)
        let location = catalog.status(of: .coreLocation)
        return "\(recognition.displayName)：\(recognition.shortLabel)；"
            + "\(assessment.displayName)：\(assessment.shortLabel)；"
            + "\(location.displayName)：\(location.shortLabel)。"
    }
}

#Preview {
    CapabilityDisclosureView(catalog: .currentDemo)
        .padding()
}
