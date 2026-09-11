import AppKit
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
        // v1.2.5: the Dashboard is a full-height left/right surface with no
        // dedicated visual title bar; keep only the native window controls.
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
                // v1.2.1: MenuBarExtra can compress a multiline SwiftUI label into
                // a single baseline on the real NSStatusItem. Render the two speed
                // rows into one fixed-size template image instead, so GitHub/Xcode
                // builds get the same deterministic two-row layout as the portable
                // AppKit implementation.
                Image(nsImage: menuBarSpeedImage)
                    .renderingMode(.template)
                    .frame(width: 55, height: 18, alignment: .bottomLeading)
                    .offset(y: 1)
                    .fixedSize(horizontal: true, vertical: true)
                    .accessibilityHidden(true)
            } else if model.menuBarShowStatus && model.menuBarShowIcon {
                Text(statusText)
                    .font(.system(size: 9.2, weight: .medium))
                    .fixedSize()
            }
        }
        .accessibilityLabel("Mihomo Core Manager, \(model.menuBarSummary)")
    }

    private var menuBarSpeedImage: NSImage {
        MenuBarSpeedImageRenderer.make(
            upload: model.menuBarRateParts(live.status?.speed?.up),
            download: model.menuBarRateParts(live.status?.speed?.down)
        )
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

private enum MenuBarSpeedImageRenderer {
    private static let imageSize = NSSize(width: 55, height: 18)
    private static let numericWidth: CGFloat = 24
    private static let unitWidth: CGFloat = 31

    static func make(
        upload: (value: String, unit: String),
        download: (value: String, unit: String)
    ) -> NSImage {
        let image = NSImage(size: imageSize, flipped: false) { _ in
            // AppKit's status button can safely host one fixed-size template image.
            // Draw upper upload and lower download rows into that image; this avoids
            // the MenuBarExtra multiline-label compression seen in GitHub builds.
            drawSpeedLine(upload, y: 8.6)
            drawSpeedLine(download, y: -0.4)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawSpeedLine(_ rate: (value: String, unit: String), y: CGFloat) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 8.3, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]

        // The numeric area always reserves four monospaced character cells. Both
        // rows start at x=0 and their unit starts at the same x position, while the
        // formatter is free to switch B/s, KB/s, MB/s, GB/s or TB/s independently.
        NSAttributedString(string: rate.value, attributes: attributes)
            .draw(in: NSRect(x: 0, y: y, width: numericWidth, height: 9.8))
        NSAttributedString(string: rate.unit, attributes: attributes)
            .draw(in: NSRect(x: numericWidth, y: y, width: unitWidth, height: 9.8))
    }
}

