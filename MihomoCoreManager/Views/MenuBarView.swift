import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore
    @Environment(\.openWindow) private var openWindow

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    private let shortcutColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                speedCard
                serverCard
                proxyMenus
                coreActions
                shortcutGrid
                updateActions
                displayOptions
                footer
            }
            .padding(14)
        }
        .frame(width: 360)
        .frame(maxHeight: 720)
        .background(DashboardPalette.background)
        .preferredColorScheme(.dark)
        .task(id: model.selectedProfileID) {
            await model.ensureProxiesLoaded()
        }
    }

    private var header: some View {
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
            statusPill
        }
    }

    private var statusPill: some View {
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
        .background(DashboardPalette.surfaceRaised.opacity(0.84))
        .clipShape(Capsule())
        .overlay { Capsule().stroke(DashboardPalette.separator, lineWidth: 1) }
    }

    private var speedCard: some View {
        HStack(spacing: 10) {
            menuSpeedMetric(
                title: "上传",
                symbol: "arrow.up",
                value: model.menuRate(live.status?.speed?.up)
            )
            Rectangle()
                .fill(DashboardPalette.separator)
                .frame(width: 1, height: 34)
            menuSpeedMetric(
                title: "下载",
                symbol: "arrow.down",
                value: model.menuRate(live.status?.speed?.down)
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(DashboardPalette.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(DashboardPalette.separator, lineWidth: 1)
        }
    }

    private func menuSpeedMetric(title: String, symbol: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DashboardPalette.accent)
                .frame(width: 18, alignment: .leading)
            VStack(alignment: .trailing, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(DashboardPalette.tertiary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
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
            .background(DashboardPalette.surface.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(DashboardPalette.separator, lineWidth: 1)
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
                                Button {
                                    guard group.now != proxyName else { return }
                                    Task { await model.selectProxy(proxyName, in: group.name) }
                                } label: {
                                    if group.now == proxyName {
                                        Label(menuProxyTitle(proxyName, group: group), systemImage: "checkmark")
                                    } else {
                                        Text(menuProxyTitle(proxyName, group: group))
                                    }
                                }
                                .disabled(model.isBusy || group.now == proxyName)
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
                        HStack(spacing: 9) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.name)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .lineLimit(1)
                                Text(group.now ?? group.type)
                                    .font(.system(size: 9.8, weight: .medium))
                                    .foregroundStyle(DashboardPalette.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            if let now = group.now {
                                Text(menuDelayText(model.effectiveProxyDelay(now, preferredTestURL: group.testURL)))
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DashboardPalette.tertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DashboardPalette.tertiary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(MenuPanelPressStyle(fillsWidth: true))
                }
            }
        }
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

    private var coreActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Core 控制")
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

    private var statusText: String {
        if live.status == nil { return "Checking" }
        return live.status?.service.active == true ? "Running" : "Stopped"
    }

    private var statusColor: Color {
        guard let status = live.status else { return .secondary }
        return status.service.active ? DashboardPalette.green : Color.orange
    }

    private func showWindow(_ section: SidebarSection) {
        model.selectedSection = section
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
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
                            : DashboardPalette.surfaceRaised.opacity(configuration.isPressed ? 0.92 : 0.66)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous)
                    .stroke(
                        selected ? DashboardPalette.accent.opacity(0.36) : DashboardPalette.separator,
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.spring(response: 0.17, dampingFraction: 0.67), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
