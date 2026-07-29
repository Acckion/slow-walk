import SwiftUI

/// The app's four top-level destinations.
///
/// Today comes first so the app opens on "what needs doing now" rather than a
/// list of tools. Anti-fraud is deliberately not a top-level tab at this stage.
enum RootDestination: Hashable, CaseIterable, Identifiable {
    case today
    case companion
    case careRecords
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "今天"
        case .companion: "陪伴"
        case .careRecords: "守护记录"
        case .settings: "关怀设置"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .companion: "figure.walk"
        case .careRecords: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }
}

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: RootDestination = .today

    var body: some View {
        // The iOS 18 `Tab` builder is deliberately not used: the app's
        // deployment target is iOS 17.0.
        TabView(selection: $selection) {
            ForEach(RootDestination.allCases) { destination in
                NavigationStack {
                    content(for: destination)
                        .navigationTitle(destination.title)
                }
                .tabItem {
                    Label(destination.title, systemImage: destination.systemImage)
                }
                .tag(destination)
            }
        }
    }

    @ViewBuilder
    private func content(for destination: RootDestination) -> some View {
        switch destination {
        case .today:
            TodayView(onStartCompanion: { selection = .companion })
        case .companion:
            CompanionView()
        case .careRecords:
            CareRecordsView()
        case .settings:
            CareSettingsView()
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment.preview())
}
