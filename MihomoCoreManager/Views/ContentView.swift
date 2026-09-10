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
                DashboardNotice(notice: notice) { model.notice = nil }
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

    private let visibleSections: [SidebarSection] = [.overview, .core, .subscriptions, .logs, .settings]

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
                        .frame(height: 43)
                        .background(model.selectedSection == section ? DashboardPalette.accent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(DashboardPressButtonStyle())
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
        .buttonStyle(DashboardPressButtonStyle())
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
                        .buttonStyle(DashboardPressButtonStyle())
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
            .buttonStyle(DashboardPressButtonStyle())
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

struct DashboardActionButtonStyle: ButtonStyle {
    var destructive = false
    var primary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled

        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(destructive ? DashboardPalette.red : .white)
            .frame(maxWidth: .infinity)
            .frame(height: DashboardLayout.actionHeight)
            .background(primary ? DashboardPalette.accent : Color.white.opacity(pressed ? 0.085 : 0.025))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(destructive ? DashboardPalette.red.opacity(0.45) : DashboardPalette.separator, lineWidth: 1)
            }
            .scaleEffect(pressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.48)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

struct DashboardPressButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled

        configuration.label
            .scaleEffect(pressed ? 0.985 : 1)
            .opacity(isEnabled ? (pressed ? 0.86 : 1) : 0.48)
            .animation(.easeOut(duration: 0.08), value: pressed)
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
            .buttonStyle(DashboardPressButtonStyle())
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
