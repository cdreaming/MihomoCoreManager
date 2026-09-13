import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var model: AppModel
    private let providers = ["BYG", "APTVPN", "XFLTD", "TAG", "ONEKING"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(
                    title: "订阅管理",
                    subtitle: "管理 Proxy Providers；保存后生成并校验 config.yaml，热重载超时时自动安全重启应用。"
                )

                DashboardPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        DashboardPanelHeader(title: "Proxy Providers", trailing: "type: http")

                        VStack(spacing: 0) {
                            ForEach(Array(providers.enumerated()), id: \.element) { index, key in
                                HStack(alignment: .center, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(key)
                                            .font(.system(size: 13, weight: .bold))
                                            .lineLimit(1)
                                        Text(String(format: "Provider %02d", index + 1))
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(DashboardPalette.tertiary)
                                    }
                                    .frame(width: 122, alignment: .leading)

                                    TextField("https://…", text: binding(for: key))
                                        .textFieldStyle(DashboardTextFieldStyle())
                                }
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) {
                                    if index != providers.count - 1 {
                                        Rectangle().fill(DashboardPalette.separator).frame(height: 1)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 9) {
                            Spacer()
                            Button { Task { await model.fetchSubscriptions() } } label: {
                                DashboardBusyLabel(title: "重新读取", busyTitle: "读取中…", isBusy: model.activeOperation == .fetchSubscriptions)
                            }
                                .buttonStyle(DashboardActionButtonStyle(busy: model.activeOperation == .fetchSubscriptions))
                                .frame(width: 120)
                            Button { Task { await model.saveSubscriptions() } } label: {
                                DashboardBusyLabel(title: "保存并应用", busyTitle: "保存应用中…", isBusy: model.activeOperation == .saveSubscriptions)
                            }
                                .buttonStyle(DashboardActionButtonStyle(primary: true, busy: model.activeOperation == .saveSubscriptions))
                                .frame(width: 140)
                        }
                        .padding(.top, 2)

                        Text("留空会由服务端生成本地 inline 占位；非空使用 Mihomo 原生 type:http。若 v4.0.0 远端热重载明确超时并回滚，App 会自动停止 Core → 保存配置 → 重新启动，以保证新订阅真正生效。")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardPalette.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.vertical, DashboardLayout.pageVerticalPadding)
        }
        .task(id: loadTaskID) {
            guard model.selectedSection == .subscriptions else { return }
            await model.ensureSubscriptionsLoaded()
        }
        .disabled(model.isBusy)
    }

    private var loadTaskID: String {
        "\(model.selectedProfileID?.uuidString ?? "none")|\(model.selectedSection.rawValue)"
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { model.subscriptions[key] ?? "" },
            set: { model.subscriptions[key] = $0 }
        )
    }
}
