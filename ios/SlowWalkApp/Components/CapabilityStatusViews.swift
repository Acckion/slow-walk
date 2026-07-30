import SwiftUI

/// One capability and what it can really do.
///
/// A pure presentation row: it renders a `CapabilityStatus` and decides
/// nothing. Status is carried by wording, never by colour alone.
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

/// The full capability list: what works, what is simulated, what is not there.
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

#Preview {
    ScrollView {
        CapabilityStatusList(catalog: .currentDemo)
            .padding()
    }
}
