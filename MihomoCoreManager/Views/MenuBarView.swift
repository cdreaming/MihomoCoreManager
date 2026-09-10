import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveStatusStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            Label("Mihomo Core", systemImage: live.status?.service.active == true ? "circle.fill" : "circle")
            Spacer()
            Text(live.status?.versions?.core ?? "--")
                .foregroundStyle(.secondary)
        }

        if model.menuBarShowSpeed {
            VStack(alignment: .center, spacing: 2) {
                Text("↑ 上传  \(model.menuRate(live.status?.speed?.up))")
                Text("↓ 下载  \(model.menuRate(live.status?.speed?.down))")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .monospacedDigit()
        }

        Divider()

        Toggle("显示图标", isOn: $model.menuBarShowIcon)
        Toggle("显示运行状态", isOn: $model.menuBarShowStatus)
        Toggle("显示网速", isOn: $model.menuBarShowSpeed)
        Button {
            model.useMenuBarIconOnly()
        } label: {
            if model.menuBarIconOnly {
                Label("仅显示图标", systemImage: "checkmark")
            } else {
                Text("仅显示图标")
            }
        }

        Divider()

        Menu("服务器：\(model.selectedProfile?.name ?? "未选择")") {
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
        }

        Button("打开主窗口") { showWindow(.overview) }
            .keyboardShortcut("o")
        Button("刷新状态") { Task { await model.refreshStatus() } }
            .keyboardShortcut("r")

        Divider()

        Button("启动 Core") { Task { await model.perform(.start) } }
            .disabled(model.isBusy || live.status?.service.active == true)
        Button("停止 Core") { Task { await model.perform(.stop) } }
            .disabled(model.isBusy || live.status?.service.active != true)
        Button("重启 Core") { Task { await model.perform(.restart) } }
            .disabled(model.isBusy)
        Button("重载配置") { Task { await model.perform(.reload) } }
            .disabled(model.isBusy)
        Button("应用订阅 + 热重载") { Task { await model.perform(.applySubscriptions) } }
            .disabled(model.isBusy)

        Divider()

        Button("订阅管理…") { showWindow(.subscriptions) }
        Button("运行日志…") { showWindow(.logs) }
        Button("项目升级…") { showWindow(.updates) }
        Button("检查项目更新") { Task { await model.checkUpdate() } }
            .disabled(model.isBusy)
        Button("开始项目升级") { Task { await model.applyUpdate() } }
            .disabled(model.isBusy)
        Button("打开 MetaCubeXD") { model.openMetaCubeXD() }

        Divider()
        Button("设置…") { showWindow(.settings) }
            .keyboardShortcut(",")
        Divider()
        Button("退出 Mihomo Core Manager") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showWindow(_ section: SidebarSection) {
        model.selectedSection = section
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
