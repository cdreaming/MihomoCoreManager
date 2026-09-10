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
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabelView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            if model.menuBarShowIcon {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 11.5, weight: .semibold))
                    .overlay(alignment: .bottomTrailing) {
                        if model.menuBarShowStatus {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 4.5, height: 4.5)
                                .overlay { Circle().stroke(Color.black.opacity(0.45), lineWidth: 0.6) }
                                .offset(x: 2, y: 1)
                        }
                    }
                    .accessibilityHidden(true)
            }

            if model.menuBarShowStatus && !model.menuBarShowIcon {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    if !model.menuBarShowSpeed {
                        Text(statusText)
                            .font(.system(size: 9.2, weight: .medium))
                    }
                }
                .fixedSize()
            }

            if model.menuBarShowSpeed {
                VStack(alignment: .leading, spacing: -2) {
                    speedLine(model.menuBarRateParts(live.status?.speed?.up))
                    speedLine(model.menuBarRateParts(live.status?.speed?.down))
                }
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .frame(width: 55, height: 18, alignment: .bottomLeading)
                .offset(y: 1)
                .fixedSize(horizontal: true, vertical: true)
            } else if model.menuBarShowStatus && model.menuBarShowIcon {
                Text(statusText)
                    .font(.system(size: 9.2, weight: .medium))
                    .fixedSize()
            }
        }
        .accessibilityLabel("Mihomo Core Manager, \(model.menuBarSummary)")
    }

    private func speedLine(_ rate: (value: String, unit: String)) -> some View {
        HStack(spacing: 0) {
            // Four monospaced character cells are always reserved for the numeric
            // part. Both rows therefore share the same left edge while B/s, KB/s,
            // MB/s and larger units can change independently.
            Text(rate.value)
                .frame(width: 24, alignment: .leading)
            Text(rate.unit)
                .frame(width: 31, alignment: .leading)
        }
        .frame(width: 55, alignment: .leading)
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
