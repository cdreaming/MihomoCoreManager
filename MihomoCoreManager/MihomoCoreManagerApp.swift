import SwiftUI

@main
struct MihomoCoreManagerApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        Window("Mihomo Core 管理面板", id: "main") {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.live)
                .preferredColorScheme(.dark)
        }
        // v1.1.2: remove the tall standard title-bar backing so the dashboard
        // can use that vertical space while preserving native window controls.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 780)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsRootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(model.live)
        } label: {
            MenuBarLabelView()
                .environmentObject(model)
                .environmentObject(model.live)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarLabelView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            if model.menuBarShowIcon {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
            }

            if model.menuBarShowStatus {
                HStack(spacing: 3) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(statusText)
                        .font(.system(size: 9.2, weight: .medium))
                        .fixedSize()
                }
            }

            if model.menuBarShowStatus && model.menuBarShowSpeed {
                Spacer()
                    .frame(width: 1)
            }

            if model.menuBarShowSpeed {
                HStack(alignment: .center, spacing: 3) {
                    VStack(alignment: .center, spacing: -2) {
                        Text("↓")
                        Text("↑")
                    }
                    VStack(alignment: .trailing, spacing: -2) {
                        Text(model.menuRateCompact(live.status?.speed?.down))
                        Text(model.menuRateCompact(live.status?.speed?.up))
                    }
                }
                .font(.system(size: 8.4, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .frame(height: 18, alignment: .center)
                .fixedSize(horizontal: true, vertical: true)
            }
        }
        .accessibilityLabel("Mihomo Core Manager, \(model.menuBarSummary)")
    }

    private var statusText: String {
        if live.status == nil { return "Checking" }
        return live.status?.service.active == true ? "Running" : "Stopped"
    }

    private var statusColor: Color {
        guard let status = live.status else { return .secondary }
        return status.service.active ? DashboardPalette.green : Color.orange
    }
}
