import AppKit
import SwiftUI

final class MihomoApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // v1.3.5: the status item is the long-lived app surface. Closing the
        // Dashboard must only close that window; the menu-bar controller stays
        // available until the explicit status-menu Quit action terminates AppKit.
        false
    }
}

@main
struct MihomoManagerApp: App {
    @NSApplicationDelegateAdaptor(MihomoApplicationDelegate.self) private var appDelegate
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
        // MenuBarExtra may collapse a compound SwiftUI label to the first image in
        // an Xcode/Release build. Render the complete status item (icon, state and
        // two speed rows) into ONE AppKit image so the GitHub .pkg gets the same
        // deterministic, variable-width status item as the portable AppKit shell.
        Image(nsImage: renderedStatusItem)
            .renderingMode(.template)
            .frame(
                width: renderedStatusItem.size.width,
                height: MenuBarStatusImageRenderer.imageHeight
            )
            .fixedSize(horizontal: true, vertical: true)
            .id(renderIdentity)
            .accessibilityLabel("MihomoManager, \(model.menuBarSummary)")
    }

    private var renderedStatusItem: NSImage {
        let rates = model.menuBarRatePair(
            upload: live.effectiveSpeed?.up,
            download: live.effectiveSpeed?.down
        )
        return MenuBarStatusImageRenderer.make(
            showIcon: model.menuBarShowIcon,
            showStatus: model.menuBarShowStatus,
            showSpeed: model.menuBarShowSpeed,
            status: statusText,
            upload: rates.upload,
            download: rates.download
        )
    }

    private var renderIdentity: String {
        let rates = model.menuBarRatePair(
            upload: live.effectiveSpeed?.up,
            download: live.effectiveSpeed?.down
        )
        let up = rates.upload
        let down = rates.download
        return [
            model.menuBarShowIcon ? "i1" : "i0",
            model.menuBarShowStatus ? "s1" : "s0",
            model.menuBarShowSpeed ? "v1" : "v0",
            statusText,
            up.value, up.unit,
            down.value, down.unit
        ].joined(separator: "|")
    }

    private var statusText: String {
        if live.status == nil { return "Checking" }
        return live.status?.service.active == true ? "Running" : "Stopped"
    }
}

private enum MenuBarStatusImageRenderer {
    static let imageHeight: CGFloat = 18

    private static let iconWidth: CGFloat = 16
    private static let statusWidth: CGFloat = 46
    private static let statusDotWidth: CGFloat = 7
    private static let gap: CGFloat = 2
    private static let speedFont = NSFont.monospacedDigitSystemFont(ofSize: 8.3, weight: .semibold)

    static func make(
        showIcon: Bool,
        showStatus: Bool,
        showSpeed: Bool,
        status: String,
        upload: (value: String, unit: String),
        download: (value: String, unit: String)
    ) -> NSImage {
        // AppModel already keeps at least one option enabled, but keep a local
        // fallback as the renderer must never create a zero-width status item.
        let effectiveIcon = showIcon || (!showStatus && !showSpeed)
        let speedMetrics = speedMetrics(upload: upload, download: download)
        let size = NSSize(
            width: imageWidth(
                showIcon: effectiveIcon,
                showStatus: showStatus,
                showSpeed: showSpeed,
                speedWidth: speedMetrics.totalWidth
            ),
            height: imageHeight
        )

        let image = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0

            if effectiveIcon {
                // v1.3.6: logo is flush with the left edge of the reserved item.
                drawIcon(in: NSRect(x: x, y: 1.2, width: iconWidth, height: iconWidth))
                x += iconWidth
            }

            // When speed is visible, use a separate state dot between the logo
            // and the speed block. The speed block itself is content-sized.
            if showStatus, showSpeed {
                if x > 0 { x += gap }
                drawDot(in: NSRect(x: x + 1.2, y: 6.9, width: 4.5, height: 4.5))
                x += statusDotWidth
            } else if showStatus {
                if x > 0 { x += gap }
                drawStatus(status, x: x)
                x += statusWidth
            }

            if showSpeed {
                let speedX = size.width - speedMetrics.totalWidth
                // Move the two traffic rows down slightly relative to v1.3.5.
                drawSpeedLine(upload, x: speedX, y: 8.0, metrics: speedMetrics)
                drawSpeedLine(download, x: speedX, y: -1.0, metrics: speedMetrics)
            }
            return true
        }
        // The whole item is a single monochrome template mask. This prevents
        // SwiftUI's MenuBarExtra label styling from dropping the traffic text.
        image.isTemplate = true
        return image
    }

    private static func imageWidth(
        showIcon: Bool,
        showStatus: Bool,
        showSpeed: Bool,
        speedWidth: CGFloat
    ) -> CGFloat {
        var width: CGFloat = 0
        if showIcon { width += iconWidth }
        if showStatus, !showSpeed {
            if width > 0 { width += gap }
            width += statusWidth
        } else if showStatus, showSpeed {
            if width > 0 { width += gap }
            width += statusDotWidth
        }
        if showSpeed {
            if width > 0 { width += gap }
            width += speedWidth
        }
        return max(18, ceil(width))
    }

    private struct SpeedMetrics {
        let numericWidth: CGFloat
        let unitWidth: CGFloat

        var totalWidth: CGFloat { numericWidth + unitWidth }
    }

    private static func speedMetrics(
        upload: (value: String, unit: String),
        download: (value: String, unit: String)
    ) -> SpeedMetrics {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: speedFont
        ]
        let numericWidth = ceil(max(
            (upload.value as NSString).size(withAttributes: attributes).width,
            (download.value as NSString).size(withAttributes: attributes).width
        ))
        // AppModel guarantees the same unit on both rows; max keeps the renderer
        // safe if a future caller violates that contract.
        let unitWidth = ceil(max(
            (upload.unit as NSString).size(withAttributes: attributes).width,
            (download.unit as NSString).size(withAttributes: attributes).width
        ))
        return SpeedMetrics(
            numericWidth: max(1, numericWidth),
            unitWidth: max(1, unitWidth)
        )
    }

    private static func drawIcon(in rect: NSRect) {
        // BrandLogo.png is byte-identical to the shared 128px AppIcon asset, so
        // SwiftUI and GoWebUI render the same source artwork in the menu bar.
        guard let base = NSImage(named: NSImage.Name("BrandLogo")),
              base.size.width > 0, base.size.height > 0 else { return }
        let scale = min(rect.width / base.size.width, rect.height / base.size.height)
        let fitted = NSSize(width: base.size.width * scale, height: base.size.height * scale)
        let drawRect = NSRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
        base.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func drawDot(in rect: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private static func drawStatus(_ status: String, x: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.0, weight: .medium),
            .foregroundColor: NSColor.black
        ]
        NSAttributedString(string: status, attributes: attributes)
            .draw(in: NSRect(x: x, y: 3.5, width: statusWidth, height: 11))
    }

    private static func drawSpeedLine(
        _ rate: (value: String, unit: String),
        x: CGFloat,
        y: CGFloat,
        metrics: SpeedMetrics
    ) {
        let numericParagraph = NSMutableParagraphStyle()
        numericParagraph.alignment = .right
        let numericAttributes: [NSAttributedString.Key: Any] = [
            .font: speedFont,
            .foregroundColor: NSColor.black,
            .paragraphStyle: numericParagraph
        ]
        let unitAttributes: [NSAttributedString.Key: Any] = [
            .font: speedFont,
            .foregroundColor: NSColor.black
        ]

        // Number column is right aligned; both unit labels begin at exactly the
        // same x coordinate and their shared unit ends flush with the right edge.
        NSAttributedString(string: rate.value, attributes: numericAttributes)
            .draw(in: NSRect(x: x, y: y, width: metrics.numericWidth, height: 9.8))
        NSAttributedString(string: rate.unit, attributes: unitAttributes)
            .draw(in: NSRect(
                x: x + metrics.numericWidth,
                y: y,
                width: metrics.unitWidth,
                height: 9.8
            ))
    }
}
