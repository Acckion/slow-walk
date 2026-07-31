import SwiftUI

/// A pure presentation row for the app's implementation capability table.
/// Status wording is carried by the injected catalog and never inferred here.
struct CapabilityStatusRow: View {
    let status: CapabilityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(status.displayName)
                    .font(.body)
                Spacer(minLength: 8)
                Text(status.shortLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let detail = status.detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.summaryLine)
    }
}

struct CapabilityStatusList: View {
    let catalog: CapabilityCatalog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(catalog.allStatuses) { status in
                CapabilityStatusRow(status: status)
            }
        }
    }
}

#Preview("Capability list") {
    ScrollView {
        CapabilityStatusList(catalog: .phase0)
            .padding()
    }
}
