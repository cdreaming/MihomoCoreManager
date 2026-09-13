import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var maximumMenuHeight = MenuBarScreenMetrics.fallbackMaximumHeight
    @State private var measuredMenuHeight: CGFloat = 0

    private let shortcutColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        Group {
            if shouldScrollMenu {
                // Only create a scroll container when the complete menu really is
                // taller than the usable area of the display.
                ScrollView(.vertical, showsIndicators: false) {
                    measuredMenuContent
                        // SwiftUI's indicator flag is not sufficient for the native
                        // MenuBarExtra NSScrollView in some Xcode Release builds.
                        // Suppress the AppKit scroller itself while preserving wheel
                        // and trackpad scrolling.
                        .background(MenuBarScrollIndicatorSuppressor())
                }
                .scrollIndicators(.hidden)
                .frame(height: maximumMenuHeight)
            } else {
                // Normal case: render the menu at its natural intrinsic height so
                // every item is visible at once and no fixed scroll box appears.
                measuredMenuContent
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 360)
        .frame(maxHeight: maximumMenuHeight)
        .background(DashboardPalette.menuBackground)
        .background(MenuBarScreenHeightReader(maximumHeight: $maximumMenuHeight))
        .background(
            MenuBarWindowConfigurator {
                // MenuBarExtra may keep the same SwiftUI tree alive between
                // presentations. Refresh the Controller snapshot every time the
                // native status window becomes key, not merely on first creation.
                Task { await model.refreshProxiesForMenuBar() }
            }
        )
        .onPreferenceChange(MenuBarContentHeightPreferenceKey.self) { height in
            guard height > 0, abs(measuredMenuHeight - height) > 0.5 else { return }
            measuredMenuHeight = height
        }
        .preferredColorScheme(.dark)
        .task(id: model.selectedProfileID) {
            // Refresh on every menu presentation instead of only the first load.
            // This keeps the selected route suffix in sync with Controller changes
            // made from MetaCubeXD, another client, or a previous menu session.
            await model.refreshProxiesForMenuBar()
        }
    }

    private var shouldScrollMenu: Bool {
        measuredMenuHeight > maximumMenuHeight + 0.5
    }

    private var measuredMenuContent: some View {
        menuContent
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MenuBarContentHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            }
    }

    private var menuContent: some View {
        VStack(spacing: 12) {
            MenuBarLiveSummary()
            serverCard
            menuSectionDivider
            proxyMenus
            menuSectionDivider
            MenuBarCoreActions()
            shortcutGrid
            updateActions
            displayOptions
            footer
        }
        .padding(14)
    }

    private var menuSectionDivider: some View {
        Rectangle()
            .fill(DashboardPalette.menuSeparator)
            .frame(height: 1)
            .padding(.vertical, 1)
    }

    private var serverCard: some View {
        Menu {
            ForEach(model.profiles) { profile in
                Button {
                    model.selectProfile(profile.id)
                } label: {
                    if model.selectedProfileID == profile.id {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "server.rack")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DashboardPalette.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("当前服务器")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(DashboardPalette.tertiary)
                    Text(model.selectedProfile?.name ?? "未选择")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DashboardPalette.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 49)
            .background(DashboardPalette.menuSurface)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(DashboardPalette.menuSeparator, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(MenuPanelPressStyle())
    }

    private var proxyMenus: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("代理组")

            if model.proxyGroupsInDefaultOrder.isEmpty {
                Button {
                    showWindow(.proxies)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(DashboardPalette.secondary)
                        Text("打开代理切换…")
                        Spacer()
                    }
                }
                .buttonStyle(MenuPanelPressStyle(fillsWidth: true))
            } else {
                ForEach(model.proxyGroupsInDefaultOrder) { group in
                    let currentSelection = model.currentProxySelection(in: group.name) ?? group.now

                    Menu {
                        Button {
                            Task { await model.testProxyGroup(group.name) }
                        } label: {
                            Label(
                                model.activeOperation == .testProxyGroup(group.name) ? "测速中…" : "测速此组",
                                systemImage: "gauge.with.dots.needle.33percent"
                            )
                        }
                        .disabled(model.isBusy && model.activeOperation != .testProxyGroup(group.name))

                        Divider()

                        if group.isSelectableGroup {
                            ForEach(group.all, id: \.self) { proxyName in
                                let selected = currentSelection == proxyName
                                Button {
                                    guard !selected else { return }
                                    Task { await model.selectProxy(proxyName, in: group.name) }
                                } label: {
                                    if selected {
                                        Label(menuProxyTitle(proxyName, group: group), systemImage: "checkmark")
                                    } else {
                                        Text(menuProxyTitle(proxyName, group: group))
                                    }
                                }
                                .disabled(model.isBusy || selected)
                            }
                        } else {
                            Text("自动策略组，不支持手动选择")
                        }

                        Divider()

                        Button {
                            showWindow(.proxies)
                        } label: {
                            Label("打开代理切换…", systemImage: "macwindow")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            // Keep group + selected route in ONE Text value. In a
                            // release MenuBarExtra, SwiftUI may collapse a custom
                            // Menu label to its primary text representation; using
                            // one title guarantees the selected `now` survives.
                            Text(proxyGroupMenuTitle(group: group, currentSelection: currentSelection))
                                .font(.system(size: 11.5, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .minimumScaleFactor(0.82)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DashboardPalette.tertiary)
                        }
                    }
                    // Force the native Menu control to rebuild when `now` changes;
                    // this avoids a cached group-only title after a route switch.
                    .id("\(group.name)|\(currentSelection ?? group.type)")
                    .menuStyle(.borderlessButton)
                    .buttonStyle(MenuPanelPressStyle(fillsWidth: true))
                }
            }
        }
    }

    private func proxyGroupMenuTitle(group: MihomoProxy, currentSelection: String?) -> String {
        let current = currentSelection?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return current.isEmpty ? group.name : "\(group.name)  ·  \(current)"
    }

    private func menuProxyTitle(_ proxyName: String, group: MihomoProxy) -> String {
        let delay = menuDelayText(model.effectiveProxyDelay(proxyName, preferredTestURL: group.testURL))
        return delay == "--" ? proxyName : "\(proxyName)  ·  \(delay)"
    }

    private func menuDelayText(_ delay: Int?) -> String {
        guard let delay else { return "--" }
        if delay <= 0 { return "超时" }
        return "\(delay) ms"
    }

    private var shortcutGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("快捷入口")
            LazyVGrid(columns: shortcutColumns, spacing: 8) {
                MenuShortcutButton(title: "主窗口", icon: "macwindow") { showWindow(.overview) }
                MenuShortcutButton(title: "订阅管理…", icon: "arrow.left.arrow.right") { showWindow(.subscriptions) }
                MenuShortcutButton(title: "运行日志…", icon: "text.alignleft") { showWindow(.logs) }
                MenuShortcutButton(title: "项目升级", icon: "arrow.up.circle") { showWindow(.updates) }
                MenuShortcutButton(title: "MetaCubeXD", icon: "safari") { model.openMetaCubeXD() }
                MenuShortcutButton(title: "设置…", icon: "gearshape") { showWindow(.settings) }
            }
        }
    }


    private var updateActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("项目维护")
            HStack(spacing: 8) {
                MenuActionButton(
                    title: "检查项目更新",
                    busyTitle: "检查中",
                    icon: "arrow.down.circle",
                    busy: model.activeOperation == .checkUpdate,
                    disabled: model.isBusy
                ) { Task { await model.checkUpdate() } }

                MenuActionButton(
                    title: "开始项目升级",
                    busyTitle: "升级中",
                    icon: "arrow.up.circle.fill",
                    busy: model.activeOperation == .applyUpdate,
                    disabled: model.isBusy
                ) { Task { await model.applyUpdate() } }
            }
        }
    }

    private var displayOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("状态栏显示")
            HStack(spacing: 7) {
                MenuToggleChip(title: "图标", isOn: $model.menuBarShowIcon)
                MenuToggleChip(title: "状态", isOn: $model.menuBarShowStatus)
                MenuToggleChip(title: "网速", isOn: $model.menuBarShowSpeed)
                Button("仅图标") { model.useMenuBarIconOnly() }
                    .font(.system(size: 10.5, weight: .semibold))
                    .buttonStyle(MenuPanelPressStyle(compact: true))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                Task { await model.refreshStatus() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(MenuPanelPressStyle(compact: true))
            .disabled(model.isBusy)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 20, height: 20)
            }
            .help("退出 Mihomo Core Manager")
            .buttonStyle(MenuPanelPressStyle(compact: true, destructive: true))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(DashboardPalette.tertiary)
            .textCase(.uppercase)
            .padding(.leading, 2)
    }

    private func showWindow(_ section: SidebarSection) {
        model.selectedSection = section
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MenuBarContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum MenuBarScreenMetrics {
    static var fallbackMaximumHeight: CGFloat {
        maximumHeight(for: NSScreen.main ?? NSScreen.screens.first)
    }

    static func maximumHeight(for screen: NSScreen?) -> CGFloat {
        // visibleFrame already excludes the menu bar and Dock. Keep a small
        // bottom margin so MenuBarExtra never lands flush against the screen.
        max(320, floor((screen?.visibleFrame.height ?? 760) - 16))
    }
}

private struct MenuBarScreenHeightReader: NSViewRepresentable {
    @Binding var maximumHeight: CGFloat

    func makeNSView(context: Context) -> MenuBarScreenTrackingView {
        let view = MenuBarScreenTrackingView()
        bind(view)
        return view
    }

    func updateNSView(_ nsView: MenuBarScreenTrackingView, context: Context) {
        bind(nsView)
        nsView.refreshScreenHeight()
    }

    private func bind(_ view: MenuBarScreenTrackingView) {
        let binding = $maximumHeight
        view.onMaximumHeightChange = { height in
            guard abs(binding.wrappedValue - height) > 0.5 else { return }
            binding.wrappedValue = height
        }
    }
}

private final class MenuBarScreenTrackingView: NSView {
    var onMaximumHeightChange: ((CGFloat) -> Void)?
    private var notificationTokens: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installObservers()
        refreshScreenHeight()
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func refreshScreenHeight() {
        let height = MenuBarScreenMetrics.maximumHeight(for: window?.screen ?? NSScreen.main ?? NSScreen.screens.first)
        onMaximumHeightChange?(height)
    }

    private func installObservers() {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()

        guard let window else { return }
        let center = NotificationCenter.default
        notificationTokens.append(
            center.addObserver(
                forName: NSWindow.didChangeScreenNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.refreshScreenHeight()
            }
        )
        notificationTokens.append(
            center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshScreenHeight()
            }
        )
    }
}

private struct MenuBarWindowConfigurator: NSViewRepresentable {
    let onPresented: () -> Void

    func makeNSView(context: Context) -> MenuBarWindowTrackingView {
        let view = MenuBarWindowTrackingView()
        view.onPresented = onPresented
        return view
    }

    func updateNSView(_ nsView: MenuBarWindowTrackingView, context: Context) {
        nsView.onPresented = onPresented
        nsView.configureCurrentWindow()
    }
}

private final class MenuBarWindowTrackingView: NSView {
    var onPresented: (() -> Void)?
    private weak var observedWindow: NSWindow?
    private var presentationObservers: [NSObjectProtocol] = []
    private var lastPresentationAt = Date.distantPast

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureCurrentWindow()
    }

    deinit {
        presentationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func configureCurrentWindow() {
        guard let window else { return }

        // Match the supplied macOS network-panel reference (#1A1A1D) at the
        // AppKit window layer as well as the SwiftUI root, so GitHub/Xcode builds
        // cannot fall back to the darker MenuBarExtra material behind our view.
        window.backgroundColor = NSColor(
            srgbRed: 26.0 / 255.0,
            green: 26.0 / 255.0,
            blue: 29.0 / 255.0,
            alpha: 1.0
        )

        guard observedWindow !== window else { return }
        presentationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        presentationObservers.removeAll()
        observedWindow = window

        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didExposeNotification] {
            presentationObservers.append(
                center.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.notifyPresented()
                }
            )
        }

        if window.isVisible {
            DispatchQueue.main.async { [weak self] in
                self?.notifyPresented()
            }
        }
    }

    private func notifyPresented() {
        // didBecomeKey can be emitted more than once during a single opening
        // animation. One refresh per presentation is enough.
        let now = Date()
        guard now.timeIntervalSince(lastPresentationAt) > 0.35 else { return }
        lastPresentationAt = now
        onPresented?()
    }
}

private struct MenuBarScrollIndicatorSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> MenuBarScrollIndicatorSuppressingView {
        let view = MenuBarScrollIndicatorSuppressingView()
        DispatchQueue.main.async { [weak view] in
            view?.suppressIndicators()
        }
        return view
    }

    func updateNSView(_ nsView: MenuBarScrollIndicatorSuppressingView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            nsView?.suppressIndicators()
        }
    }
}

private final class MenuBarScrollIndicatorSuppressingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.suppressIndicators()
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        DispatchQueue.main.async { [weak self] in
            self?.suppressIndicators()
        }
    }

    override func layout() {
        super.layout()
        suppressIndicators()
    }

    func suppressIndicators() {
        guard let scrollView = nearestScrollView() else { return }
        // Removing the NSScroller does NOT disable scrolling. Wheel, trackpad,
        // keyboard and accessibility scrolling keep working normally.
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScroller?.isHidden = true
        scrollView.verticalScroller?.alphaValue = 0
        scrollView.horizontalScroller?.isHidden = true
        scrollView.horizontalScroller?.alphaValue = 0
    }

    private func nearestScrollView() -> NSScrollView? {
        var candidate: NSView? = self
        while let view = candidate {
            if let scrollView = view as? NSScrollView { return scrollView }
            if let scrollView = view.enclosingScrollView { return scrollView }
            candidate = view.superview
        }
        return nil
    }
}

private struct MenuBarLiveSummary: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [DashboardPalette.accent, Color(red: 0.39, green: 0.30, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .shadow(color: DashboardPalette.accent.opacity(0.22), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mihomo Core")
                        .font(.system(size: 15, weight: .bold))
                    Text(live.status?.versions?.core ?? "正在读取版本…")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(DashboardPalette.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: statusColor.opacity(0.45), radius: 4)
                    Text(statusText)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .frame(height: 29)
                .background(DashboardPalette.menuSurfaceRaised)
                .clipShape(Capsule())
                .overlay { Capsule().stroke(DashboardPalette.menuSeparator, lineWidth: 1) }
            }

            HStack(spacing: 9) {
                speedMetric(
                    title: "上传",
                    symbol: "arrow.up",
                    value: model.menuRate(live.status?.speed?.up)
                )

                Spacer(minLength: 6)
                Rectangle()
                    .fill(DashboardPalette.menuSeparator)
                    .frame(width: 1, height: 18)
                Spacer(minLength: 6)

                speedMetric(
                    title: "下载",
                    symbol: "arrow.down",
                    value: model.menuRate(live.status?.speed?.down)
                )
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(DashboardPalette.menuSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardPalette.menuSeparator, lineWidth: 1)
            }
        }
    }

    private func speedMetric(title: String, symbol: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(DashboardPalette.accent)
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(DashboardPalette.tertiary)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
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

private struct MenuBarCoreActions: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Core 控制")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(DashboardPalette.tertiary)
                .textCase(.uppercase)
                .padding(.leading, 2)

            LazyVGrid(columns: columns, spacing: 8) {
                MenuActionButton(
                    title: "启动",
                    busyTitle: "启动中",
                    icon: "play.fill",
                    busy: model.activeOperation == .core(.start),
                    disabled: model.isBusy || live.status?.service.active == true
                ) { Task { await model.perform(.start) } }

                MenuActionButton(
                    title: "停止",
                    busyTitle: "停止中",
                    icon: "stop.fill",
                    busy: model.activeOperation == .core(.stop),
                    disabled: model.isBusy || live.status?.service.active != true,
                    role: .destructive,
                    destructive: true
                ) { Task { await model.perform(.stop) } }

                MenuActionButton(
                    title: "重启",
                    busyTitle: "重启中",
                    icon: "arrow.clockwise",
                    busy: model.activeOperation == .core(.restart),
                    disabled: model.isBusy
                ) { Task { await model.perform(.restart) } }

                MenuActionButton(
                    title: "重载配置",
                    busyTitle: "重载中",
                    icon: "doc.badge.arrow.up",
                    busy: model.activeOperation == .core(.reload),
                    disabled: model.isBusy
                ) { Task { await model.perform(.reload) } }
            }

            MenuActionButton(
                title: "应用订阅 + 热重载",
                busyTitle: "正在应用订阅",
                icon: "arrow.triangle.2.circlepath",
                busy: model.activeOperation == .core(.applySubscriptions),
                disabled: model.isBusy,
                fillsWidth: true
            ) { Task { await model.perform(.applySubscriptions) } }
        }
    }
}

private struct MenuActionButton: View {
    let title: String
    let busyTitle: String
    let icon: String
    let busy: Bool
    let disabled: Bool
    var role: ButtonRole? = nil
    var destructive = false
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 7) {
                if busy {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.78)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(busy ? busyTitle : title)
                    .lineLimit(1)
            }
            .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .buttonStyle(MenuPanelPressStyle(fillsWidth: true, destructive: destructive))
        .disabled(disabled)
        .opacity(disabled ? 0.46 : 1)
    }
}

private struct MenuShortcutButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DashboardPalette.secondary)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(MenuPanelPressStyle(fillsWidth: true))
    }
}

private struct MenuToggleChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isOn ? DashboardPalette.accent : DashboardPalette.tertiary)
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
            }
        }
        .buttonStyle(MenuPanelPressStyle(compact: true, selected: isOn))
    }
}

private struct MenuPanelPressStyle: ButtonStyle {
    var compact = false
    var fillsWidth = false
    var destructive = false
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
            .foregroundStyle(destructive ? DashboardPalette.red : Color.primary)
            .padding(.horizontal, compact ? 9 : 11)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: compact ? 30 : 36)
            .background(
                RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous)
                    .fill(
                        selected
                            ? DashboardPalette.accent.opacity(configuration.isPressed ? 0.26 : 0.18)
                            : DashboardPalette.menuSurfaceRaised.opacity(configuration.isPressed ? 0.96 : 0.84)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous)
                    .stroke(
                        selected ? DashboardPalette.accent.opacity(0.36) : DashboardPalette.menuSeparator,
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.spring(response: 0.17, dampingFraction: 0.67), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
