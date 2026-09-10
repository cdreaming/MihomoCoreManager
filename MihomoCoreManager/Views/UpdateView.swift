import SwiftUI

struct UpdateView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(
                    title: "项目升级",
                    subtitle: "检查并升级 Mihomo Core、MetaCubeXD 与 Core 管理面板。"
                )

                DashboardPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        DashboardPanelHeader(title: "版本检查", trailing: "Remote project")
                        HStack(spacing: 9) {
                            Button("检查新版本") { Task { await model.checkUpdate() } }
                                .buttonStyle(DashboardActionButtonStyle())
                            Button("开始项目升级") { Task { await model.applyUpdate() } }
                                .buttonStyle(DashboardActionButtonStyle(primary: true))
                        }
                        .disabled(model.isBusy)

                        if let info = model.updateInfo {
                            VStack(spacing: 0) {
                                versionRow("Mihomo Core", info.coreCurrent, info.coreLatest, info.coreUpdateAvailable)
                                versionRow("MetaCubeXD", info.metacubexdCurrent, info.metacubexdLatest, info.metacubexdUpdateAvailable)
                                versionRow("Core 管理面板", info.managementPanelCurrent, info.managementPanelLatest ?? info.managementPanelBundled, info.managementPanelUpdateAvailable)
                            }
                            .background(DashboardPalette.field.opacity(0.58))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DashboardPalette.separator, lineWidth: 1)
                            }
                        } else {
                            Text("尚未检查。")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardPalette.tertiary)
                        }

                        HStack {
                            Text("设置参数")
                                .foregroundStyle(DashboardPalette.secondary)
                            Spacer()
                            Text(model.selectedProfile?.preserveSettingsOnUpdate == true ? "保留现有参数" : "不保留，使用默认参数")
                                .foregroundStyle(DashboardPalette.tertiary)
                            Button("修改…") { model.selectedSection = .settings }
                                .buttonStyle(DashboardPressButtonStyle())
                                .foregroundStyle(DashboardPalette.accent)
                        }
                        .font(.system(size: 11.5))
                    }
                }

                DashboardPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        DashboardPanelHeader(title: model.updateRunning ? "升级进行中" : "升级日志", trailing: model.updateRunning ? "RUNNING" : nil)
                        ScrollView([.horizontal, .vertical]) {
                            Text(model.updateLogs.isEmpty ? "(no update log)" : model.updateLogs)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Color(red: 0.82, green: 0.85, blue: 0.90))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(2)
                        }
                        .frame(minHeight: 220)
                        .background(DashboardPalette.field.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DashboardPalette.separator, lineWidth: 1)
                        }

                        HStack {
                            Spacer()
                            Button("刷新升级日志") { Task { await model.fetchUpdateLog() } }
                                .buttonStyle(DashboardActionButtonStyle())
                                .frame(width: 132)
                        }
                    }
                }
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.vertical, DashboardLayout.pageVerticalPadding)
        }
        .disabled(model.isBusy)
    }

    @ViewBuilder
    private func versionRow(_ name: String, _ current: String?, _ latest: String?, _ available: Bool?) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .foregroundStyle(DashboardPalette.secondary)
                .frame(width: 128, alignment: .leading)
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
        .overlay(alignment: .bottom) { Rectangle().fill(DashboardPalette.separator).frame(height: 1) }
    }
}
