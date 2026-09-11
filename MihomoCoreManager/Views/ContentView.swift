import AppKit
import SwiftUI

enum DashboardPalette {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.082)
    static let sidebar = Color(red: 0.095, green: 0.108, blue: 0.133)
    static let surface = Color(red: 0.118, green: 0.127, blue: 0.153)
    static let surfaceRaised = Color(red: 0.135, green: 0.145, blue: 0.175)
    static let field = Color(red: 0.102, green: 0.112, blue: 0.138)
    static let separator = Color.white.opacity(0.105)
    static let secondary = Color(red: 0.62, green: 0.66, blue: 0.73)
    static let tertiary = Color(red: 0.46, green: 0.51, blue: 0.59)
    static let accent = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.23)
}

enum DashboardLayout {
    static let pageHorizontalPadding: CGFloat = 28
    static let pageVerticalPadding: CGFloat = 26
    static let pageSpacing: CGFloat = 22
    static let sectionSpacing: CGFloat = 14
    static let panelSpacing: CGFloat = 12
    static let actionHeight: CGFloat = 38
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            DashboardSidebar()
                .frame(width: 230)

            Rectangle()
                .fill(DashboardPalette.separator)
                .frame(width: 1)

            persistentDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DashboardPalette.background)
        .background(WindowBehaviorConfigurator().frame(width: 0, height: 0))
        .frame(minWidth: 1000, minHeight: 650)
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                DashboardNotice(notice: notice) { model.dismissNotice() }
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.notice)
    }

    private var persistentDetail: some View {
        ZStack {
            persistentPage(.overview) { OverviewView() }
            persistentPage(.core) { CoreView() }
            persistentPage(.proxies) { ProxiesView() }
            persistentPage(.subscriptions) { SubscriptionsView() }
            persistentPage(.logs) { LogsView() }
            persistentPage(.updates) { UpdateView() }
            persistentPage(.settings) { DashboardSettingsView() }
        }
    }

    @ViewBuilder
    private func persistentPage<Content: View>(
        _ section: SidebarSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let active = model.selectedSection == section
        content()
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
            .zIndex(active ? 1 : 0)
    }

}

/// Re-applies the normal macOS window movement behavior even when the Dashboard
/// uses a full-window custom background. The title bar remains a standard drag
/// target, and empty background areas can also start a native window drag.
private struct WindowBehaviorConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView) }
    }

    private func configure(_ view: NSView) {
        guard let window = view.window else { return }

        // v1.1.2 compact title bar: keep the native traffic-light controls,
        // remove the oversized title backing, and let the dashboard occupy it.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)

        window.isMovable = true
        window.isMovableByWindowBackground = true
    }
}

private struct DashboardSidebar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    private let visibleSections: [SidebarSection] = [.overview, .core, .proxies, .subscriptions, .logs, .settings]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.59, blue: 1.0), Color(red: 0.43, green: 0.32, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text("M")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: DashboardPalette.accent.opacity(0.22), radius: 18, y: 8)

                Text("Mihomo Core")
                    .font(.system(size: 17, weight: .bold))

                VStack(alignment: .leading, spacing: 3) {
                    sidebarVersion("Core 版本", live.status?.versions?.core ?? "--")
                    sidebarVersion("Core 面板", live.status?.versions?.managementPanel ?? "v4.0.0")
                    sidebarVersion("MetaCubeXD", live.status?.versions?.metacubexd ?? "--")
                }

            }
            .padding(.horizontal, 22)
            // Clear the native traffic-light controls now that content extends
            // into the title-bar region, without recreating a tall top strip.
            .padding(.top, 38)
            .padding(.bottom, 14)

            VStack(spacing: 6) {
                ForEach(visibleSections) { section in
                    Button {
                        model.selectedSection = section
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(model.selectedSection == section ? Color.white.opacity(0.14) : Color.white.opacity(0.045))
                                Image(systemName: sidebarIcon(section))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(width: 27, height: 27)

                            Text(section.title)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(model.selectedSection == section ? .white : DashboardPalette.secondary)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 47, alignment: .leading)
                        .background(model.selectedSection == section ? DashboardPalette.accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(DashboardSidebarButtonStyle())
                    .frame(maxWidth: .infinity)
                }

                DashboardBackendSelector()
                    .environmentObject(model)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 20)

            HStack(spacing: 7) {
                Circle()
                    .fill(live.status?.service.active == true ? DashboardPalette.green : DashboardPalette.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: (live.status?.service.active == true ? DashboardPalette.green : DashboardPalette.red).opacity(0.42), radius: 5)
                Text(panelLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardPalette.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 29)
            .background(Color.white.opacity(0.025))
            .clipShape(Capsule())
            .overlay { Capsule().stroke(DashboardPalette.separator, lineWidth: 1) }
            .padding(.leading, 22)
            .padding(.bottom, 22)
        }
        .background(DashboardPalette.sidebar)
    }

    @ViewBuilder
    private func sidebarVersion(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + "：")
            Text(value)
                .lineLimit(1)
        }
        .font(.system(size: 11))
        .foregroundStyle(DashboardPalette.tertiary)
    }

    private func sidebarIcon(_ section: SidebarSection) -> String {
        switch section {
        case .overview: "arrow.up.left.and.arrow.down.right"
        case .core: "dot.circle"
        case .proxies: "arrow.triangle.branch"
        case .subscriptions: "arrow.left.arrow.right"
        case .logs: "command"
        case .updates: "arrow.down.circle"
        case .settings: "gearshape"
        }
    }

    private var panelLabel: String {
        if let raw = live.status?.management?.publicUrl,
           let url = URL(string: raw), let port = url.port {
            return "Panel :\(port)"
        }
        if let raw = model.selectedProfile?.managementURL,
           let url = URL(string: raw), let port = url.port {
            return "Panel :\(port)"
        }
        return "Panel · Remote"
    }
}

private struct DashboardSidebarButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .scaleEffect(pressed ? 0.972 : 1)
            .offset(y: pressed ? 1.5 : 0)
            .brightness(pressed ? -0.08 : 0)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(pressed ? 0.075 : 0))
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(pressed ? 0.08 : 0), radius: 2, y: 1)
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.68), value: pressed)
    }
}

private struct DashboardBackendSelector: View {
    @EnvironmentObject private var model: AppModel
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isPresented ? Color.white.opacity(0.075) : Color.white.opacity(0.045))
                    Image(systemName: "server.rack")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(width: 27, height: 27)

                Text("管理后端")
                    .font(.system(size: 14, weight: .semibold))

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(DashboardPalette.tertiary)
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
            }
            .foregroundStyle(DashboardPalette.secondary)
            .padding(.horizontal, 10)
            .frame(height: 43)
            .background(isPresented ? Color.white.opacity(0.035) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("切换 Mihomo Core 后端服务器")
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            BackendPickerPopover(isPresented: $isPresented)
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

private struct BackendPickerPopover: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("管理后端")
                        .font(.system(size: 14, weight: .semibold))
                    Text("选择要管理的 Mihomo Core 服务器")
                        .font(.system(size: 10.5))
                        .foregroundStyle(DashboardPalette.tertiary)
                }
                Spacer(minLength: 10)
                Text("\(model.profiles.count) 个配置")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(DashboardPalette.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)

            Rectangle()
                .fill(DashboardPalette.separator)
                .frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.profiles) { profile in
                        let selected = model.selectedProfileID == profile.id
                        Button {
                            model.selectProfile(profile.id)
                            isPresented = false
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(profile.name)
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        if !model.hasSecret(for: profile.id) {
                                            Image(systemName: "exclamationmark.circle")
                                                .font(.system(size: 9.5, weight: .semibold))
                                                .foregroundStyle(Color.orange.opacity(0.9))
                                                .help("该服务器尚未保存 Core Secret")
                                        }
                                    }
                                    Text(backendEndpointText(profile))
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(DashboardPalette.tertiary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 12)

                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(DashboardPalette.accent)
                                }
                            }
                            .padding(.horizontal, 11)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(selected ? DashboardPalette.accent.opacity(0.085) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 320)

            Rectangle()
                .fill(DashboardPalette.separator)
                .frame(height: 1)

            Button {
                model.selectedSection = .settings
                isPresented = false
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "gearshape")
                    Text("服务器设置…")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DashboardPalette.tertiary)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardPalette.secondary)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        // Match the popover content width to the sidebar trigger exactly:
        // 230pt sidebar - 12pt leading - 12pt trailing = 206pt.
        .frame(width: 206)
        .background(DashboardPalette.surfaceRaised)
    }
}

private func backendEndpointText(_ profile: ServerProfile?) -> String {
    guard let profile,
          let url = URL(string: profile.managementURL),
          let host = url.host else {
        return "Mihomo Core 后端"
    }
    if let port = url.port { return "\(host):\(port)" }
    return host
}

struct DashboardPageHeader: View {
    let title: String
    let subtitle: String
    @EnvironmentObject private var live: LiveStatusStore

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 29, weight: .bold))
                    .tracking(-0.6)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardPalette.secondary)
            }
            Spacer(minLength: 12)
            DashboardStatusBadge(running: live.status?.service.active == true)
        }
    }
}

struct DashboardStatusBadge: View {
    let running: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(running ? DashboardPalette.green : DashboardPalette.red)
                .frame(width: 9, height: 9)
                .shadow(color: (running ? DashboardPalette.green : DashboardPalette.red).opacity(0.45), radius: 5)
            Text(running ? "Running" : "Stopped")
                .font(.system(size: 13, weight: .bold))
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(DashboardPalette.surface.opacity(0.82))
        .clipShape(Capsule())
        .overlay { Capsule().stroke(DashboardPalette.separator, lineWidth: 1) }
    }
}

struct DashboardPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DashboardPalette.surface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DashboardPalette.separator, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.14), radius: 18, y: 9)
    }
}

struct DashboardPanelHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardPalette.tertiary)
            }
        }
    }
}

struct DashboardBusyLabel: View {
    let title: String
    let busyTitle: String
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isBusy {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .scaleEffect(0.82)
            }
            Text(isBusy ? busyTitle : title)
        }
        .animation(.easeInOut(duration: 0.12), value: isBusy)
    }
}

private final class DashboardBusyCursorAnimator {
    static let shared = DashboardBusyCursorAnimator()

    private var timer: Timer?
    private var frameIndex = 0
    private lazy var cursors = (0..<12).map(Self.makeCursor)

    func start(animated: Bool) {
        stop(resetCursor: false)
        frameIndex = 0
        cursors[frameIndex].set()
        if !animated {
            return
        }
        let timer = Timer(timeInterval: 0.075, repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop(resetCursor: Bool = true) {
        timer?.invalidate()
        timer = nil
        if resetCursor {
            NSCursor.arrow.set()
        }
    }

    private func advance() {
        frameIndex = (frameIndex + 1) % cursors.count
        cursors[frameIndex].set()
    }

    private static func makeCursor(frame: Int) -> NSCursor {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size, flipped: false) { _ in
            let center = NSPoint(x: 11, y: 11)
            let radiusInner: CGFloat = 5.2
            let radiusOuter: CGFloat = 8.0

            NSColor.black.withAlphaComponent(0.20).setFill()
            NSBezierPath(ovalIn: NSRect(x: 1.5, y: 1.5, width: 19, height: 19)).fill()

            for segment in 0..<8 {
                let phase = (segment - frame + 96) % 8
                let alpha = 0.24 + CGFloat(phase + 1) * 0.095
                let angle = CGFloat(segment) * (.pi / 4) - (.pi / 2)
                let start = NSPoint(
                    x: center.x + cos(angle) * radiusInner,
                    y: center.y + sin(angle) * radiusInner
                )
                let end = NSPoint(
                    x: center.x + cos(angle) * radiusOuter,
                    y: center.y + sin(angle) * radiusOuter
                )
                let path = NSBezierPath()
                path.lineWidth = 2.1
                path.lineCapStyle = .round
                path.move(to: start)
                path.line(to: end)
                NSColor.white.withAlphaComponent(min(alpha, 1)).setStroke()
                path.stroke()
            }
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 11, y: 11))
    }
}

private struct DashboardButtonCursorModifier: ViewModifier {
    let busy: Bool
    let reduceMotion: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
                updateCursor(inside: inside, busy: busy)
            }
            .onChange(of: busy) { newValue in
                guard hovering else { return }
                updateCursor(inside: true, busy: newValue)
            }
            .onDisappear {
                if hovering {
                    DashboardBusyCursorAnimator.shared.stop()
                }
            }
    }

    private func updateCursor(inside: Bool, busy: Bool) {
        guard inside else {
            DashboardBusyCursorAnimator.shared.stop()
            return
        }
        if busy {
            DashboardBusyCursorAnimator.shared.start(animated: !reduceMotion)
        } else {
            DashboardBusyCursorAnimator.shared.stop(resetCursor: false)
            NSCursor.pointingHand.set()
        }
    }
}

struct DashboardActionButtonStyle: ButtonStyle {
    var destructive = false
    var primary = false
    var busy = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !busy

        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(destructive ? DashboardPalette.red : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                primary
                    ? DashboardPalette.accent.opacity(pressed ? 0.78 : 1)
                    : Color.white.opacity(pressed ? 0.14 : (busy ? 0.055 : 0.025))
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        destructive ? DashboardPalette.red.opacity(pressed ? 0.72 : 0.45) : DashboardPalette.separator,
                        lineWidth: pressed ? 1.5 : 1
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(pressed ? 0.075 : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(pressed ? 0.955 : 1)
            .offset(y: pressed ? 1 : 0)
            .shadow(color: Color.black.opacity(pressed ? 0.08 : 0.20), radius: pressed ? 1 : 4, y: pressed ? 0 : 2)
            .opacity(busy ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.68), value: pressed)
            .modifier(DashboardButtonCursorModifier(busy: busy, reduceMotion: reduceMotion))
    }
}

struct DashboardTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(DashboardPalette.field)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardPalette.separator, lineWidth: 1)
            }
    }
}

private struct DashboardNotice: View {
    let notice: AppNotice
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(notice.isError ? DashboardPalette.red : DashboardPalette.green)
            Text(notice.text)
                .lineLimit(2)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(DashboardPalette.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(DashboardPalette.surfaceRaised.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardPalette.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
    }
}


struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedGroupName: String?
    @State private var searchText = ""
    @State private var groupSort: ProxySortOption = .defaultOrder
    @State private var proxySort: ProxySortOption = .defaultOrder

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(
                    title: "代理切换",
                    subtitle: "直接连接 Mihomo Core Controller，支持分组排序、组内测速与线路切换。"
                )

                runModePanel
                proxyWorkspace
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.vertical, DashboardLayout.pageVerticalPadding)
        }
        .task(id: loadTaskID) {
            guard model.selectedSection == .proxies else { return }
            await model.ensureProxiesLoaded()
            normalizeSelection()
        }
        .onChange(of: groupNames) { _, _ in normalizeSelection() }
    }

    private var runModePanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 14) {
                DashboardPanelHeader(
                    title: "运行模式",
                    trailing: controllerConfigured ? "Direct Controller" : "未配置 Controller"
                )

                HStack(spacing: 10) {
                    ForEach(MihomoRunMode.allCases) { mode in
                        let selected = model.proxyMode == mode
                        let busy = model.activeOperation == .setProxyMode(mode)
                        Button {
                            Task { await model.setProxyMode(mode) }
                        } label: {
                            HStack(spacing: 8) {
                                if busy {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: mode.systemImage)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                Text(mode.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .foregroundStyle(selected ? .white : DashboardPalette.secondary)
                            .padding(.horizontal, 13)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(selected ? DashboardPalette.accent : DashboardPalette.field)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selected ? DashboardPalette.accent : DashboardPalette.separator, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isBusy)
                    }
                }

                HStack(spacing: 7) {
                    Image(systemName: "network")
                    Text(controllerText)
                        .textSelection(.enabled)
                }
                .font(.system(size: 11))
                .foregroundStyle(DashboardPalette.tertiary)
            }
        }
    }

    private var proxyWorkspace: some View {
        HStack(alignment: .top, spacing: DashboardLayout.sectionSpacing) {
            DashboardPanel {
                VStack(alignment: .leading, spacing: 12) {
                    DashboardPanelHeader(title: "代理组", trailing: "\(groups.count) groups")
                    sortControl(selection: $groupSort)

                    if groups.isEmpty {
                        emptyState(
                            icon: "arrow.triangle.branch",
                            title: "尚未读取到代理组",
                            detail: "确认 Core 正在运行，并检查 Controller URL 与 Controller Secret。"
                        )
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(groups) { group in
                                groupRow(group)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        Task {
                            await model.fetchProxies()
                            normalizeSelection()
                        }
                    } label: {
                        DashboardBusyLabel(
                            title: "刷新代理",
                            busyTitle: "刷新中…",
                            isBusy: model.activeOperation == .fetchProxies
                        )
                    }
                    .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .fetchProxies))
                    .disabled(model.isBusy && model.activeOperation != .fetchProxies)
                }
                .frame(maxWidth: .infinity, minHeight: 470, alignment: .topLeading)
            }
            .frame(width: 310)

            DashboardPanel {
                if let group = selectedGroup {
                    groupDetail(group)
                        .frame(maxWidth: .infinity, minHeight: 470, alignment: .topLeading)
                } else {
                    emptyState(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "请选择代理组",
                        detail: "从左侧选择一个代理组查看、测速并切换详细代理。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 470)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func groupRow(_ group: MihomoProxy) -> some View {
        let selected = selectedGroupName == group.name
        let currentDelay = groupCurrentDelay(group)

        return Button {
            selectedGroupName = group.name
            searchText = ""
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(group.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(group.type)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(selected ? Color.white.opacity(0.8) : DashboardPalette.tertiary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(group.alive == false ? DashboardPalette.red : DashboardPalette.green)
                        .frame(width: 6, height: 6)
                    Text(group.now ?? "未选择")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(selected ? Color.white.opacity(0.88) : DashboardPalette.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(delayText(currentDelay))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selected ? Color.white.opacity(0.78) : delayColor(currentDelay, alive: currentProxy(for: group)?.alive))
                    Text("\(group.all.count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selected ? Color.white.opacity(0.75) : DashboardPalette.tertiary)
                }
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(selected ? DashboardPalette.accent : DashboardPalette.field.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? DashboardPalette.accent : DashboardPalette.separator, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func groupDetail(_ group: MihomoProxy) -> some View {
        let speedOperation = AppOperation.testProxyGroup(group.name)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 18, weight: .bold))
                    HStack(spacing: 8) {
                        detailBadge(group.type, accent: false)
                        detailBadge(group.isSelectableGroup ? "可切换" : "自动策略", accent: group.isSelectableGroup)
                        if let now = group.now {
                            detailBadge("当前 · \(now)", accent: true)
                        }
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        Task { await model.testProxyGroup(group.name) }
                    } label: {
                        DashboardBusyLabel(
                            title: "测速当前组",
                            busyTitle: "测速中…",
                            isBusy: model.activeOperation == speedOperation
                        )
                    }
                    .buttonStyle(DashboardActionButtonStyle(
                        primary: true,
                        busy: model.activeOperation == speedOperation
                    ))
                    .frame(width: 126)
                    .disabled(model.isBusy && model.activeOperation != speedOperation)

                    Text("\(filteredMembers.count) / \(group.all.count) 个代理")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(DashboardPalette.tertiary)
                }
            }

            HStack(spacing: 10) {
                TextField("筛选代理…", text: $searchText)
                    .textFieldStyle(DashboardTextFieldStyle())
                sortControl(selection: $proxySort)
                    .frame(width: 300)
            }

            Rectangle()
                .fill(DashboardPalette.separator)
                .frame(height: 1)

            if filteredMembers.isEmpty {
                emptyState(icon: "magnifyingglass", title: "没有匹配的代理", detail: "调整筛选关键字后重试。")
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                LazyVStack(spacing: 7) {
                    ForEach(filteredMembers, id: \.self) { name in
                        proxyRow(name: name, group: group)
                    }
                }
            }
        }
    }

    private func proxyRow(name: String, group: MihomoProxy) -> some View {
        let proxy = proxyByName[name]
        let selected = group.now == name
        let operation = AppOperation.selectProxy(group: group.name, proxy: name)
        let busy = model.activeOperation == operation
        let effectiveDelay = model.effectiveProxyDelay(name, preferredTestURL: group.testURL)

        return Button {
            guard group.isSelectableGroup, !selected else { return }
            Task { await model.selectProxy(name, in: group.name) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selected ? DashboardPalette.accent : DashboardPalette.field)
                    if busy {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                    } else if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .fill(proxy?.alive == false ? DashboardPalette.red : DashboardPalette.green)
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 12.5, weight: selected ? .bold : .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 9) {
                        Text(proxy?.type ?? "Unknown")
                        capabilityText("UDP", enabled: proxy?.udp)
                        capabilityText("XUDP", enabled: proxy?.xudp)
                        capabilityText("TFO", enabled: proxy?.tfo)
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(DashboardPalette.tertiary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(delayText(effectiveDelay))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(delayColor(effectiveDelay, alive: proxy?.alive))
                    Text(selected ? "当前使用" : (group.isSelectableGroup ? "点击切换" : "自动选择"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(DashboardPalette.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(selected ? DashboardPalette.accent.opacity(0.09) : DashboardPalette.field.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? DashboardPalette.accent.opacity(0.58) : DashboardPalette.separator, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy || !group.isSelectableGroup || selected)
        .opacity(group.isSelectableGroup || selected ? 1 : 0.86)
    }

    private var defaultGroups: [MihomoProxy] {
        model.proxyGroupsInDefaultOrder
    }

    private var groups: [MihomoProxy] {
        switch groupSort {
        case .defaultOrder:
            return defaultGroups
        case .delay:
            return defaultGroups.sorted { groupDelayLess($0, $1) }
        case .quality:
            return defaultGroups.sorted { qualityLess(groupProxyName($0), groupProxyName($1)) }
        case .name:
            return defaultGroups.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private var groupNames: [String] { defaultGroups.map(\.name) }

    private var selectedGroup: MihomoProxy? {
        guard let selectedGroupName else { return defaultGroups.first }
        return defaultGroups.first(where: { $0.name == selectedGroupName }) ?? defaultGroups.first
    }

    private var proxyByName: [String: MihomoProxy] {
        model.proxies.reduce(into: [:]) { result, proxy in
            result[proxy.name] = proxy
        }
    }

    private var filteredMembers: [String] {
        guard let group = selectedGroup else { return [] }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = group.all.filter { keyword.isEmpty || $0.lowercased().contains(keyword) }

        switch proxySort {
        case .defaultOrder:
            return filtered
        case .delay:
            return filtered.sorted { delayLess($0, $1) }
        case .quality:
            return filtered.sorted { qualityLess($0, $1) }
        case .name:
            return filtered.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }
    }

    private var controllerText: String {
        let value = model.selectedProfile?.coreControllerURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "请先在设置中配置 Direct Core Controller URL" : value
    }

    private var controllerConfigured: Bool {
        !controllerText.hasPrefix("请先")
    }

    private var loadTaskID: String {
        "\(model.selectedProfileID?.uuidString ?? "none")|\(model.selectedSection.rawValue)"
    }

    private func normalizeSelection() {
        if let selectedGroupName, groupNames.contains(selectedGroupName) { return }
        self.selectedGroupName = defaultGroups.first?.name
    }

    private func sortControl(selection: Binding<ProxySortOption>) -> some View {
        Picker("排序", selection: selection) {
            ForEach(ProxySortOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func groupProxyName(_ group: MihomoProxy) -> String {
        group.now ?? group.name
    }

    private func currentProxy(for group: MihomoProxy) -> MihomoProxy? {
        guard let now = group.now else { return proxyByName[group.name] }
        return proxyByName[now] ?? proxyByName[group.name]
    }

    private func groupCurrentDelay(_ group: MihomoProxy) -> Int? {
        if let now = group.now {
            return model.effectiveProxyDelay(now, preferredTestURL: group.testURL)
        }
        return model.effectiveProxyDelay(group.name, preferredTestURL: group.testURL)
    }

    private func groupDelayLess(_ lhs: MihomoProxy, _ rhs: MihomoProxy) -> Bool {
        let l = groupCurrentDelay(lhs)
        let r = groupCurrentDelay(rhs)
        switch (validDelay(l), validDelay(r)) {
        case let (lv?, rv?):
            if lv != rv { return lv < rv }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func delayLess(_ lhs: String, _ rhs: String) -> Bool {
        let l = validDelay(model.effectiveProxyDelay(lhs))
        let r = validDelay(model.effectiveProxyDelay(rhs))
        switch (l, r) {
        case let (lv?, rv?):
            if lv != rv { return lv < rv }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private func validDelay(_ delay: Int?) -> Int? {
        guard let delay, delay > 0 else { return nil }
        return delay
    }

    private struct QualityKey {
        let aliveRank: Int
        let failureCount: Int
        let jitter: Int
        let averageDelay: Double
        let latestDelay: Int
        let name: String
    }

    private func qualityKey(_ name: String) -> QualityKey {
        let proxy = proxyByName[name]
        let preferredTestURL = selectedGroup?.testURL
        let aliveRank: Int
        switch proxy?.alive {
        case true: aliveRank = 0
        case nil: aliveRank = 1
        case false: aliveRank = 2
        }

        let history = Array(proxy?.history.suffix(6) ?? [])
        var positive = history.compactMap(\.delay).filter { $0 > 0 }
        var failures = history.compactMap(\.delay).filter { $0 <= 0 }.count

        if let tested = model.proxyDelayResults[name] {
            if tested > 0 {
                positive.append(tested)
            } else {
                failures += 1
            }
        }

        let average = positive.isEmpty
            ? Double.greatestFiniteMagnitude
            : Double(positive.reduce(0, +)) / Double(positive.count)
        let jitter = positive.count >= 2
            ? (positive.max() ?? 0) - (positive.min() ?? 0)
            : (positive.isEmpty ? Int.max : 0)
        let latest = validDelay(model.effectiveProxyDelay(name, preferredTestURL: preferredTestURL)) ?? Int.max

        return QualityKey(
            aliveRank: aliveRank,
            failureCount: failures,
            jitter: jitter,
            averageDelay: average,
            latestDelay: latest,
            name: name
        )
    }

    private func qualityLess(_ lhs: String, _ rhs: String) -> Bool {
        let l = qualityKey(lhs)
        let r = qualityKey(rhs)
        if l.aliveRank != r.aliveRank { return l.aliveRank < r.aliveRank }
        if l.failureCount != r.failureCount { return l.failureCount < r.failureCount }
        if l.jitter != r.jitter { return l.jitter < r.jitter }
        if l.averageDelay != r.averageDelay { return l.averageDelay < r.averageDelay }
        if l.latestDelay != r.latestDelay { return l.latestDelay < r.latestDelay }
        return l.name.localizedCaseInsensitiveCompare(r.name) == .orderedAscending
    }

    private func capabilityText(_ name: String, enabled: Bool?) -> some View {
        Group {
            if enabled == true {
                Text(name)
            }
        }
    }

    private func detailBadge(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(accent ? DashboardPalette.accent : DashboardPalette.secondary)
            .padding(.horizontal, 8)
            .frame(height: 23)
            .background((accent ? DashboardPalette.accent : DashboardPalette.field).opacity(accent ? 0.12 : 0.8))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(accent ? DashboardPalette.accent.opacity(0.32) : DashboardPalette.separator, lineWidth: 1)
            }
    }

    private func delayText(_ delay: Int?) -> String {
        guard let delay else { return "-- ms" }
        if delay <= 0 { return "超时" }
        return "\(delay) ms"
    }

    private func delayColor(_ delay: Int?, alive: Bool?) -> Color {
        if alive == false { return DashboardPalette.red }
        guard let delay else { return DashboardPalette.tertiary }
        if delay <= 0 { return DashboardPalette.red }
        if delay < 150 { return DashboardPalette.green }
        if delay < 350 { return Color.orange }
        return DashboardPalette.red
    }

    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(DashboardPalette.tertiary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardPalette.secondary)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(DashboardPalette.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
