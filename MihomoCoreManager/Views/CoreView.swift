import SwiftUI

struct CoreView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(
                    title: "Core 控制",
                    subtitle: "优先使用 Mihomo Controller API 与 Core 服务面板 API；SSH/mihomo.service 仅显式配置后作为末级回退。"
                )

                serviceColumns
                corePortPanel
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.top, DashboardLayout.pageTopPadding)
            .padding(.bottom, DashboardLayout.pageBottomPadding)
        }
        .task(id: model.selectedProfileID) {
            await model.ensurePortsLoaded()
        }
    }

    private var serviceColumns: some View {
        HStack(alignment: .top, spacing: DashboardLayout.sectionSpacing) {
            serviceInfo
                .frame(width: 334)
            serviceControl
                .frame(maxWidth: .infinity)
        }
    }

    private var serviceControl: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 12) {
                DashboardPanelHeader(title: "服务控制", trailing: "Mihomo Core")

                Grid(horizontalSpacing: 9, verticalSpacing: 9) {
                    GridRow {
                        Button { Task { await model.perform(.start) } } label: {
                            DashboardBusyLabel(title: "启动 Core", busyTitle: "启动中…", isBusy: model.activeOperation == .core(.start))
                        }
                            .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .core(.start)))
                            .disabled(live.status?.service.active == true || model.isBusy || !model.coreLifecycleAvailable)
                        Button { Task { await model.perform(.stop) } } label: {
                            DashboardBusyLabel(title: "停止 Core", busyTitle: "停止中…", isBusy: model.activeOperation == .core(.stop))
                        }
                            .buttonStyle(DashboardActionButtonStyle(destructive: true, busy: model.activeOperation == .core(.stop)))
                            .disabled(live.status?.service.active != true || model.isBusy || !model.coreLifecycleAvailable)
                    }
                    GridRow {
                        Button { Task { await model.perform(.restart) } } label: {
                            DashboardBusyLabel(title: "重启 Core", busyTitle: "重启中…", isBusy: model.activeOperation == .core(.restart))
                        }
                            .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .core(.restart)))
                            .disabled(model.isBusy || !model.coreRestartAvailable)
                        Button { Task { await model.perform(.reload) } } label: {
                            DashboardBusyLabel(title: "热重载配置", busyTitle: "重载中…", isBusy: model.activeOperation == .core(.reload))
                        }
                            .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .core(.reload)))
                            .disabled(model.isBusy || !model.coreRestartAvailable)
                    }
                }
                .frame(maxWidth: .infinity)

                Button { Task { await model.perform(.applySubscriptions) } } label: {
                    DashboardBusyLabel(title: "重新生成配置并热重载", busyTitle: "应用中…", isBusy: model.activeOperation == .core(.applySubscriptions))
                }
                    .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .core(.applySubscriptions)))
                    .disabled(model.isBusy || !model.managementFeaturesAvailable)

                Button { model.openMetaCubeXD() } label: {
                    Text("打开 MetaCubeXD")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(DashboardActionButtonStyle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("MetaCubeXD 独立面板：http://127.0.0.1:29091")
                    Text("配置文件：/usr/local/libexec/Mihomo-Web-Panel/env/metacubexd-panel.env")
                    Text("重启/热重载先走 Mihomo Controller API；服务生命周期与日志随后走 Core 服务面板 API；")
                    Text("只有显式配置 SSH 目标时才尝试 mihomo.service；避免因局域网直连失败而自动触发 SSH 认证；")
                }
                .font(.system(size: 11))
                .foregroundStyle(DashboardPalette.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            }
            .frame(maxWidth: .infinity, minHeight: 328, alignment: .topLeading)
        }
    }

    private var corePortPanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    DashboardPanelHeader(title: "Core 端口设置", trailing: "双列 · config.yaml")
                    Spacer(minLength: 8)
                    Button { Task { await model.fetchPorts() } } label: {
                        DashboardBusyLabel(title: "重新读取", busyTitle: "读取中…", isBusy: model.activeOperation == .fetchPorts)
                    }
                    .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .fetchPorts))
                    .frame(width: 108)
                    .disabled(model.isBusy || !model.managementFeaturesAvailable)
                }

                if let settings = model.portManagement?.settings.filter({ $0.editable }), !settings.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8, alignment: .top),
                        GridItem(.flexible(), spacing: 8, alignment: .top),
                    ], spacing: 8) {
                        ForEach(settings) { setting in
                            CorePortSettingRow(setting: setting)
                                .environmentObject(model)
                        }
                    }
                } else {
                    Text(model.managementFeaturesAvailable
                         ? "尚未读取到可编辑端口。请确认 Core 服务面板已升级到 v4.1.2。"
                         : "配置 Management URL 与 Secret 后，可在此安全修改 config.yaml 中的 Core 端口。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(DashboardPalette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                updateSection
            }
        }
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardPanelHeader(title: "项目升级", trailing: "Mihomo Core + MetaCubeXD + Core 管理面板")

            HStack(spacing: 9) {
                Button { Task { await model.checkUpdate() } } label: {
                    DashboardBusyLabel(title: "检查新版本", busyTitle: "检查中…", isBusy: model.activeOperation == .checkUpdate)
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .checkUpdate))
                    .frame(maxWidth: .infinity)
                Button { Task { await model.applyUpdate() } } label: {
                    DashboardBusyLabel(title: "开始项目升级", busyTitle: "项目升级中…", isBusy: model.activeOperation == .applyUpdate)
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(DashboardActionButtonStyle(primary: true, busy: model.activeOperation == .applyUpdate))
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .disabled(model.isBusy || !model.managementFeaturesAvailable)

            HStack {
                Text("升级策略")
                    .foregroundStyle(DashboardPalette.secondary)
                Spacer()
                Text(model.selectedProfile?.preserveSettingsOnUpdate == true ? "保留现有参数" : "不保留，使用默认参数")
                    .foregroundStyle(DashboardPalette.tertiary)
                Button("修改…") { model.selectedSection = .settings }
                    .buttonStyle(.plain)
                    .foregroundStyle(DashboardPalette.accent)
            }
            .font(.system(size: 11.5))

            if let info = model.updateInfo {
                VStack(spacing: 0) {
                    versionRow("Mihomo Core", info.coreCurrent, info.coreLatest, info.coreUpdateAvailable)
                    versionRow("MetaCubeXD", info.metacubexdCurrent, info.metacubexdLatest, info.metacubexdUpdateAvailable)
                    versionRow("Core 管理面板", info.managementPanelCurrent, info.managementPanelLatest ?? info.managementPanelBundled, info.managementPanelUpdateAvailable, isLast: true)
                }
                .background(DashboardPalette.field.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DashboardPalette.separator, lineWidth: 1)
                }
            } else {
                Text("尚未检查。点击“检查新版本”读取远端版本状态。")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardPalette.tertiary)
            }
        }
    }

    private var serviceInfo: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 0) {
                DashboardPanelHeader(title: "服务信息", trailing: live.status?.versions?.core ?? "--")
                    .padding(.bottom, 6)
                infoRow("状态", live.status?.service.active == true ? "RUNNING" : "STOPPED", accent: true)
                infoRow("服务详情", serviceDetail)
                infoRow("运行时间", uptime)
                infoRow("内存", bytes(live.status?.memoryBytes))
                infoRow("连接数", String(live.status?.connections ?? 0))
                infoRow("PID", pid)
                infoRow("Unit", live.status?.service.unitFilePath ?? (model.selectedProfile?.hasSystemdServiceEndpoint == true ? "mihomo.service" : "--"), selectable: true)
                infoRow("Controller", live.status?.controller ?? "--", selectable: true)
                infoRow("config.yaml", model.selectedProfile?.configPath ?? "--", selectable: true, isLast: true)
            }
            .frame(maxWidth: .infinity, minHeight: 328, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String, accent: Bool = false, selectable: Bool = false, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .foregroundStyle(DashboardPalette.secondary)
                .frame(width: 90, alignment: .leading)

            Group {
                if selectable {
                    Text(value)
                        .textSelection(.enabled)
                } else {
                    Text(value)
                }
            }
            .foregroundStyle(accent ? (live.status?.service.active == true ? DashboardPalette.green : DashboardPalette.red) : .white)
            .fontWeight(accent ? .bold : .regular)
            .multilineTextAlignment(.trailing)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 12))
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(DashboardPalette.separator).frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private func versionRow(_ name: String, _ current: String?, _ latest: String?, _ available: Bool?, isLast: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .foregroundStyle(DashboardPalette.secondary)
                .frame(width: 126, alignment: .leading)
            Text(current ?? "--")
            Image(systemName: "arrow.right")
                .foregroundStyle(DashboardPalette.tertiary)
            Text(latest ?? "--")
            Spacer()
            Text(available == true ? "可升级" : "已最新")
                .foregroundStyle(available == true ? DashboardPalette.accent : DashboardPalette.green)
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 11)
        .frame(height: 36)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(DashboardPalette.separator).frame(height: 1)
            }
        }
    }

    private var serviceDetail: String {
        let manager = live.status?.service.manager ?? "--"
        let state = live.status?.service.subState ?? "--"
        let enabled: String
        switch live.status?.service.enabled {
        case .some(true): enabled = "autostart ON"
        case .some(false): enabled = "autostart OFF"
        case .none: enabled = "autostart --"
        }
        return "\(manager) · \(state) · \(enabled)"
    }

    private var pid: String {
        guard let pid = live.status?.service.pid, pid > 0 else { return "--" }
        return String(pid)
    }

    private var uptime: String {
        let seconds = Int(live.status?.uptimeSeconds ?? 0)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        return "\(hours)h \(minutes)m"
    }

    private func bytes(_ value: Int64?) -> String {
        ByteCountFormatter.string(fromByteCount: value ?? 0, countStyle: .memory)
    }
}

private struct CorePortSettingRow: View {
    @EnvironmentObject private var model: AppModel
    let setting: CorePortSetting
    @State private var enabled: Bool
    @State private var portText: String

    init(setting: CorePortSetting) {
        self.setting = setting
        _enabled = State(initialValue: setting.kind == "scalar" ? setting.configured : true)
        _portText = State(initialValue: setting.port.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(setting.label)
                        .font(.system(size: 11, weight: .semibold))
                    Text(setting.description)
                        .font(.system(size: 9.5))
                        .foregroundStyle(DashboardPalette.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)

                if setting.optional {
                    Toggle("启用", isOn: $enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                TextField("端口", text: $portText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(DashboardPalette.field)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(DashboardPalette.separator, lineWidth: 1)
                    }
                    .disabled(!enabled)

                Button { save() } label: {
                    DashboardBusyLabel(
                        title: "保存",
                        busyTitle: "保存中…",
                        isBusy: model.activeOperation == .savePortSetting(setting.id)
                    )
                }
                .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .savePortSetting(setting.id)))
                .frame(width: 88, height: 38)
                .disabled(model.isBusy || !model.managementFeaturesAvailable)
            }
        }
        .padding(9)
        .background(DashboardPalette.field.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(DashboardPalette.separator, lineWidth: 1)
        }
        .onChange(of: setting.port) { _, newValue in
            portText = newValue.map(String.init) ?? ""
        }
        .onChange(of: setting.configured) { _, newValue in
            if setting.kind == "scalar" { enabled = newValue }
        }
    }

    private func save() {
        let port: Int?
        if enabled {
            guard let value = Int(portText), (1...65_535).contains(value) else {
                model.show("端口必须在 1-65535 之间", error: true)
                return
            }
            port = value
        } else {
            port = nil
        }
        Task { await model.savePortSetting(setting, enabled: enabled, port: port) }
    }
}

struct LinePortsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(
                    title: "线路端口",
                    subtitle: "查看受管线路端口、对应线路/代理组与当前延时，并可逐条刷新测速。"
                )

                DashboardPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            DashboardPanelHeader(
                                title: "线路端口信息",
                                trailing: "\(model.portManagement?.routeCount ?? 0) 条映射"
                            )
                            Spacer(minLength: 8)
                            Button { Task { await model.fetchPorts() } } label: {
                                DashboardBusyLabel(
                                    title: "刷新线路端口",
                                    busyTitle: "读取中…",
                                    isBusy: model.activeOperation == .fetchPorts
                                )
                            }
                            .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .fetchPorts))
                            .disabled(model.isBusy || !model.managementFeaturesAvailable)
                        }

                        if let routes = model.portManagement?.routes, !routes.isEmpty {
                            routeHeader
                            VStack(spacing: 7) {
                                ForEach(routes) { route in
                                    routeRow(route)
                                }
                            }
                        } else {
                            Text(model.managementFeaturesAvailable
                                 ? "当前 config.yaml 没有可显示的受管线路端口，或尚未从 Core 服务面板读取成功。"
                                 : "请先在“服务设置”中配置 Management URL 与 Secret，再读取线路端口信息。")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardPalette.tertiary)
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
                                .multilineTextAlignment(.center)
                        }

                        Text("每条“刷新延时”仅测试对应线路或代理组；Provider 线路优先使用单节点 healthcheck，代理组使用 Controller 延时接口。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(DashboardPalette.tertiary)
                    }
                }
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.top, DashboardLayout.pageTopPadding)
            .padding(.bottom, DashboardLayout.pageBottomPadding)
        }
        .task(id: model.selectedProfileID) {
            await model.ensurePortsLoaded()
        }
    }

    private var routeHeader: some View {
        HStack(spacing: 10) {
            Text("端口").frame(width: 72, alignment: .leading)
            Text("端口类型").frame(width: 132, alignment: .leading)
            Text("对应线路 / 代理组").frame(maxWidth: .infinity, alignment: .leading)
            Text("延时").frame(width: 72, alignment: .trailing)
            Text("操作").frame(width: 96, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(DashboardPalette.tertiary)
        .padding(.horizontal, 11)
    }

    private func routeRow(_ route: LinePortRoute) -> some View {
        HStack(spacing: 10) {
            Text(String(route.port))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 72, alignment: .leading)

            Text(route.portType)
                .font(.system(size: 11))
                .foregroundStyle(DashboardPalette.secondary)
                .frame(width: 132, alignment: .leading)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.target)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Text(routeMetadata(route))
                    .font(.system(size: 9.5))
                    .foregroundStyle(DashboardPalette.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(delayText(route.delay))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(delayColor(route.delay))
                .frame(width: 72, alignment: .trailing)

            Button { Task { await model.refreshRouteDelay(route) } } label: {
                DashboardBusyLabel(
                    title: "刷新延时",
                    busyTitle: "测速中…",
                    isBusy: model.activeOperation == .refreshRouteDelay(route.target)
                )
            }
            .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .refreshRouteDelay(route.target)))
            .disabled(model.isBusy || model.portManagement?.serviceActive != true)
            .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(DashboardPalette.field.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(DashboardPalette.separator, lineWidth: 1)
        }
    }

    private func routeMetadata(_ route: LinePortRoute) -> String {
        let label = route.kindLabel.isEmpty ? (route.kind == "group" ? "代理组" : "线路") : route.kindLabel
        guard let provider = route.provider, !provider.isEmpty else { return label }
        return "\(label) · \(provider)"
    }

    private func delayText(_ delay: Int?) -> String {
        guard let delay, delay > 0 else { return "-- ms" }
        return "\(delay) ms"
    }

    private func delayColor(_ delay: Int?) -> Color {
        guard let delay, delay > 0 else { return DashboardPalette.tertiary }
        if delay < 150 { return DashboardPalette.green }
        if delay < 350 { return .orange }
        return DashboardPalette.red
    }
}
