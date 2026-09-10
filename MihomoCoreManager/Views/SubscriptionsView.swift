import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var model: AppModel
    private let providers = ["BYG", "APTVPN", "XFLTD", "TAG", "ONEKING"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DashboardPageHeader(
                    title: "订阅管理",
                    subtitle: "管理 Proxy Providers；保存后生成并校验 config.yaml，热重载超时时自动安全重启应用。"
                )

                DashboardPanel {
                    VStack(alignment: .leading, spacing: 0) {
                        DashboardPanelHeader(title: "Proxy Providers", trailing: "type: http")
                            .padding(.bottom, 8)

                        ForEach(Array(providers.enumerated()), id: \.element) { index, key in
                            HStack(spacing: 18) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key)
                                        .font(.system(size: 13, weight: .bold))
                                    Text(String(format: "Provider %02d", index + 1))
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(DashboardPalette.tertiary)
                                }
                                .frame(width: 105, alignment: .leading)

                                TextField("https://…", text: binding(for: key))
                                    .textFieldStyle(DashboardTextFieldStyle())
                            }
                            .padding(.vertical, 9)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(DashboardPalette.separator).frame(height: 1)
                            }
                        }

                        HStack(spacing: 9) {
                            Spacer()
                            Button("重新读取") { Task { await model.fetchSubscriptions() } }
                                .buttonStyle(DashboardActionButtonStyle())
                                .frame(width: 120)
                            Button("保存并应用") { Task { await model.saveSubscriptions() } }
                                .buttonStyle(DashboardActionButtonStyle(primary: true))
                                .frame(width: 140)
                        }
                        .padding(.top, 14)

                        Text("留空会由服务端生成本地 inline 占位；非空使用 Mihomo 原生 type:http。若 v4.0.0 远端热重载明确超时并回滚，App 会自动停止 Core → 保存配置 → 重新启动，以保证新订阅真正生效。")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardPalette.tertiary)
                            .padding(.top, 12)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
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
