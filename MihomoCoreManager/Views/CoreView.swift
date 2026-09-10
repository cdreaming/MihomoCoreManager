import SwiftUI

struct CoreView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(
                    title: "Core 控制",
                    subtitle: "仅管理 Mihomo Core 进程；MetaCubeXD 与管理面板保持独立。"
                )

                serviceColumns
                metaCubePanel
                updatePanel
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.vertical, DashboardLayout.pageVerticalPadding)
        }
    }

    private var serviceColumns: some View {
        HStack(alignment: .top, spacing: DashboardLayout.sectionSpacing) {
            serviceControl
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            serviceInfo
                .frame(maxWidth: .infinity)
                .frame(height: 300)
        }
    }

    private var serviceControl: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 12) {
                DashboardPanelHeader(title: "服务控制", trailing: "Mihomo Core")

                Grid(horizontalSpacing: 9, verticalSpacing: 9) {
                    GridRow {
                        Button("启动 Core") { Task { await model.perform(.start) } }
                            .buttonStyle(DashboardActionButtonStyle())
                            .disabled(live.status?.service.active == true || model.isBusy)
                        Button("停止 Core") { Task { await model.perform(.stop) } }
                            .buttonStyle(DashboardActionButtonStyle(destructive: true))
                            .disabled(live.status?.service.active != true || model.isBusy)
                    }
                    GridRow {
                        Button("重启 Core") { Task { await model.perform(.restart) } }
                            .buttonStyle(DashboardActionButtonStyle())
                            .disabled(model.isBusy)
                        Button("热重载配置") { Task { await model.perform(.reload) } }
                            .buttonStyle(DashboardActionButtonStyle())
                            .disabled(model.isBusy)
                    }
                }
                .frame(maxWidth: .infinity)

                Button("重新生成配置并热重载") { Task { await model.perform(.applySubscriptions) } }
                    .buttonStyle(DashboardActionButtonStyle())
                    .disabled(model.isBusy)

                Spacer(minLength: 0)

                Text("生命周期动作由远端 Mihomo Core 管理面板 v4.0.0 API 执行；config.yaml 路径可在设置中指定。")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardPalette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                infoRow("Controller", live.status?.controller ?? "--", selectable: true)
                infoRow("config.yaml", model.selectedProfile?.configPath ?? "--", selectable: true, isLast: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var metaCubePanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 12) {
                DashboardPanelHeader(title: "MetaCubeXD", trailing: "Proxy Network Panel")
                Button("打开 MetaCubeXD") { model.openMetaCubeXD() }
                    .buttonStyle(DashboardActionButtonStyle())
                Text(model.resolvedMetaCubeXDURL?.absoluteString ?? "尚未配置 MetaCubeXD URL")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardPalette.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private var updatePanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 12) {
                DashboardPanelHeader(title: "项目升级", trailing: "Mihomo Core + MetaCubeXD + Core 管理面板")

                HStack(spacing: 9) {
                    Button("检查新版本") { Task { await model.checkUpdate() } }
                        .buttonStyle(DashboardActionButtonStyle())
                    Button("开始项目升级") { Task { await model.applyUpdate() } }
                        .buttonStyle(DashboardActionButtonStyle(primary: true))
                }
                .disabled(model.isBusy)

                HStack {
                    Text("升级策略")
                        .foregroundStyle(DashboardPalette.secondary)
                    Spacer()
                    Text(model.selectedProfile?.preserveSettingsOnUpdate == true ? "保留现有参数" : "不保留，使用默认参数")
                        .foregroundStyle(DashboardPalette.tertiary)
                    Button("修改…") { model.selectedSection = .settings }
                        .buttonStyle(DashboardPressButtonStyle())
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
        let enabled = live.status?.service.enabled == true ? "autostart ON" : "autostart OFF"
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
