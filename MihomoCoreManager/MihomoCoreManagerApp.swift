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
        .defaultSize(width: 1220, height: 780)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsRootView()
                .environmentObject(model)
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
        HStack(alignment: .center, spacing: 4) {
            if model.menuBarShowIcon {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 10.5, weight: .semibold))
                    .frame(width: 11, height: 11, alignment: .center)
                    .accessibilityHidden(true)
            }

            if model.menuBarShowStatus {
                HStack(spacing: 2) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(compactStatusText)
                        .font(.system(size: 8.8, weight: .medium))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: 11, alignment: .center)
            }

            if model.menuBarShowSpeed {
                HStack(alignment: .center, spacing: 2) {
                    VStack(alignment: .center, spacing: -1) {
                        Image(systemName: "arrow.down")
                        Image(systemName: "arrow.up")
                    }
                    .font(.system(size: 6, weight: .semibold))
                    .frame(width: 7, height: 14, alignment: .center)

                    VStack(alignment: .trailing, spacing: -1) {
                        Text(model.menuRateCompact(live.status?.speed?.down))
                        Text(model.menuRateCompact(live.status?.speed?.up))
                    }
                    .frame(height: 14, alignment: .center)
                }
                .font(.system(size: 8.0, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
            }
        }
        .frame(height: 18, alignment: .center)
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        .accessibilityLabel("Mihomo Core Manager, \(model.menuBarSummary)")
    }

    private var compactStatusText: String {
        if live.status == nil { return "Wait" }
        return live.status?.service.active == true ? "On" : "Off"
    }

    private var statusColor: Color {
        guard let status = live.status else { return .secondary }
        return status.service.active ? DashboardPalette.green : Color.orange
    }
}
