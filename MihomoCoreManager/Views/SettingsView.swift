import AppKit
import SwiftUI


struct DashboardSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var draft: ServerProfile?
    @State private var secret = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DashboardPageHeader(
                    title: "设置",
                    subtitle: "服务器、Core 配置、状态栏显示与刷新策略。"
                )

                DashboardPanel {
                    HStack(spacing: 10) {
                        Text("当前服务器")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardPalette.secondary)
                        Menu(model.selectedProfile?.name ?? "未选择") {
                            ForEach(model.profiles) { profile in
                                Button(profile.name) { model.selectProfile(profile.id) }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        Spacer()
                        Button("新增服务器") {
                            model.addProfile()
                            loadDraft()
                        }
                        .buttonStyle(DashboardActionButtonStyle())
                        .frame(width: 112)
                        Button("删除服务器") {
                            if let id = model.selectedProfileID {
                                model.removeProfile(id)
                                loadDraft()
                            }
                        }
                        .buttonStyle(DashboardActionButtonStyle(destructive: true))
                        .frame(width: 112)
                        .disabled(model.profiles.count <= 1)
                    }
                }

                if let draftBinding = Binding($draft) {
                    connectionPanel(profile: draftBinding)
                    corePanel(profile: draftBinding)
                    appPanel

                    HStack {
                        Text("Core Secret 仅保存到 macOS Keychain；Profile 文件不包含 Secret。")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardPalette.tertiary)
                        Spacer()
                        Button("测试连接") {
                            saveDraft()
                            Task { await model.refreshStatus() }
                        }
                        .buttonStyle(DashboardActionButtonStyle())
                        .frame(width: 110)
                        Button("保存设置") { saveDraft() }
                            .buttonStyle(DashboardActionButtonStyle(primary: true))
                            .frame(width: 120)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
        }
        .task(id: loadTaskID) {
            guard model.selectedSection == .settings else { return }
            loadDraft()
        }
    }

    @ViewBuilder
    private func connectionPanel(profile: Binding<ServerProfile>) -> some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 12) {
                DashboardPanelHeader(title: "服务器连接", trailing: "Cross-machine")
                settingRow("名称") {
                    TextField("服务器名称", text: profile.name)
                        .textFieldStyle(DashboardTextFieldStyle())
                }
                settingRow("Management URL") {
                    TextField("https://…", text: profile.managementURL)
                        .textContentType(.URL)
                        .textFieldStyle(DashboardTextFieldStyle())
                }
                settingRow("Core Secret") {
                    HStack(spacing: 8) {
                        SecureField("留空表示不修改 Keychain", text: $secret)
                            .textFieldStyle(DashboardTextFieldStyle())
                        Button("粘贴") { pasteSecret() }
                            .buttonStyle(DashboardActionButtonStyle())
                            .frame(width: 76)
                        Button("清除") {
                            secret = ""
                            if let id = model.selectedProfileID { model.saveSecret("", for: id) }
                        }
                        .buttonStyle(DashboardActionButtonStyle(destructive: true))
                        .frame(width: 76)
                    }
                }
                Toggle("允许不安全 HTTP", isOn: profile.allowInsecureHTTP)
                    .toggleStyle(.switch)
            }
        }
    }

    @ViewBuilder
    private func corePanel(profile: Binding<ServerProfile>) -> some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 12) {
                DashboardPanelHeader(title: "Core 配置", trailing: "v4.0.0 API baseline")
                settingRow("Direct Controller URL") {
                    TextField("可选", text: profile.coreControllerURL)
                        .textContentType(.URL)
                        .textFieldStyle(DashboardTextFieldStyle())
                }
                settingRow("config.yaml path") {
                    TextField("/etc/mihomo/config.yaml", text: profile.configPath)
                        .textFieldStyle(DashboardTextFieldStyle())
                }
                settingRow("MetaCubeXD URL") {
                    TextField("可选", text: profile.metaCubeXDURL)
                        .textContentType(.URL)
                        .textFieldStyle(DashboardTextFieldStyle())
                }
                Toggle("项目升级时保留现有设置", isOn: profile.preserveSettingsOnUpdate)
                    .toggleStyle(.switch)
            }
        }
    }

    private var appPanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: 12) {
                DashboardPanelHeader(title: "App 与状态栏", trailing: "Performance")
                Toggle("显示状态栏按钮", isOn: $showMenuBarExtra)
                    .toggleStyle(.switch)
                Toggle("状态栏显示图标", isOn: $model.menuBarShowIcon)
                    .toggleStyle(.switch)
                Toggle("状态栏显示运行状态", isOn: $model.menuBarShowStatus)
                    .toggleStyle(.switch)
                Toggle("状态栏显示实时网速（上传 / 下载上下两行）", isOn: $model.menuBarShowSpeed)
                    .toggleStyle(.switch)
                HStack(spacing: 14) {
                    Text("状态刷新间隔")
                        .foregroundStyle(DashboardPalette.secondary)
                    Picker("", selection: $model.refreshInterval) {
                        Text("1 秒").tag(1.0)
                        Text("1.2 秒").tag(1.2)
                        Text("2 秒").tag(2.0)
                        Text("5 秒").tag(5.0)
                        Text("10 秒").tag(10.0)
                    }
                    .labelsHidden()
                    .frame(width: 120)
                    Text("默认日志行数")
                        .foregroundStyle(DashboardPalette.secondary)
                    Picker("", selection: $model.logLines) {
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                        Text("300").tag(300)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    Spacer()
                    Button("仅显示图标") { model.useMenuBarIconOnly() }
                        .buttonStyle(DashboardActionButtonStyle())
                        .frame(width: 110)
                        .disabled(model.menuBarIconOnly)
                }
                .font(.system(size: 12))
            }
        }
    }

    @ViewBuilder
    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(DashboardPalette.secondary)
                .frame(width: 170, alignment: .leading)
            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 3)
    }

    private var loadTaskID: String {
        "\(model.selectedProfileID?.uuidString ?? "none")|\(model.selectedSection.rawValue)"
    }

    private func loadDraft() {
        draft = model.selectedProfile
        if let id = model.selectedProfileID {
            secret = KeychainStore.readSecret(profileID: id)
        } else {
            secret = ""
        }
    }

    private func saveDraft() {
        guard let draft else { return }
        model.updateProfile(draft)
        if !secret.isEmpty { model.saveSecret(secret, for: draft.id) }
        model.show("设置已保存")
    }

    private func pasteSecret() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            model.show("剪贴板中没有可粘贴的文本。", error: true)
            return
        }
        secret = value.trimmingCharacters(in: .newlines)
    }
}

struct SettingsRootView: View {
    var body: some View {
        TabView {
            ProfilesSettingsView()
                .tabItem { Label("服务器", systemImage: "server.rack") }
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(width: 720, height: 520)
    }
}

private struct ProfilesSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(model.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                HStack(spacing: 8) {
                    Button {
                        model.addProfile()
                        selection = model.selectedProfileID
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        if let selection {
                            model.removeProfile(selection)
                            self.selection = model.selectedProfileID
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.profiles.count <= 1 || selection == nil)
                    Spacer()
                }
                .padding(8)
                .overlay(alignment: .top) { Divider() }
            }
            .frame(minWidth: 165, idealWidth: 180, maxWidth: 210)

            if let id = selection ?? model.selectedProfileID,
               let binding = profileBinding(id: id) {
                ProfileEditorView(profile: binding)
                    .id(id)
                    .frame(minWidth: 500)
            } else {
                ContentUnavailableView("请选择服务器", systemImage: "server.rack")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { selection = model.selectedProfileID }
        .onChange(of: selection) { _, newValue in
            if let newValue { model.selectProfile(newValue) }
        }
    }

    private func profileBinding(id: UUID) -> Binding<ServerProfile>? {
        guard model.profiles.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { model.profiles.first(where: { $0.id == id }) ?? .blank() },
            set: { model.updateProfile($0) }
        )
    }
}

private struct ProfileEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var profile: ServerProfile
    @State private var secret = ""

    var body: some View {
        Form {
            Section("连接") {
                LabeledContent("名称") {
                    TextField("服务器名称", text: $profile.name)
                        .frame(minWidth: 300)
                }
                LabeledContent("Management URL") {
                    TextField("https://…", text: $profile.managementURL)
                        .textContentType(.URL)
                        .frame(minWidth: 300)
                }
                LabeledContent("Core Secret") {
                    HStack(spacing: 6) {
                        SecureField("Core Secret", text: $secret)
                            .frame(minWidth: 230)
                        Button {
                            pasteSecret()
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .help("从剪贴板粘贴 Core Secret")
                        Button("保存") { model.saveSecret(secret, for: profile.id) }
                    }
                }
                HStack {
                    Text("支持 ⌘V；Secret 仅保存到 macOS Keychain。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清除 Secret", role: .destructive) {
                        secret = ""
                        model.saveSecret("", for: profile.id)
                    }
                }
                Toggle("允许不安全 HTTP", isOn: $profile.allowInsecureHTTP)
            }

            Section("Core 配置") {
                LabeledContent("Direct Core Controller URL") {
                    TextField("可选", text: $profile.coreControllerURL)
                        .textContentType(.URL)
                        .frame(minWidth: 300)
                }
                LabeledContent("config.yaml path") {
                    TextField("/etc/mihomo/config.yaml", text: $profile.configPath)
                        .frame(minWidth: 300)
                }
                Text("Controller URL 非空时直接调用 Mihomo `/configs?force=true`；为空时回退到 v4.0.0 管理面板 reload。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("面板与升级") {
                LabeledContent("MetaCubeXD URL") {
                    TextField("可选", text: $profile.metaCubeXDURL)
                        .textContentType(.URL)
                        .frame(minWidth: 300)
                }
                Toggle("项目升级时保留现有设置", isOn: $profile.preserveSettingsOnUpdate)
            }

            Section {
                Button("测试连接") { Task { await model.refreshStatus() } }
                    .disabled(model.isBusy)
            }
        }
        .formStyle(.grouped)
        .task(id: profile.id) { secret = KeychainStore.readSecret(profileID: profile.id) }
    }

    private func pasteSecret() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            model.show("剪贴板中没有可粘贴的文本。", error: true)
            return
        }
        secret = value.trimmingCharacters(in: .newlines)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some View {
        Form {
            Section("界面") {
                Toggle("显示状态栏按钮", isOn: $showMenuBarExtra)
                Toggle("状态栏显示图标", isOn: $model.menuBarShowIcon)
                Toggle("状态栏显示运行状态", isOn: $model.menuBarShowStatus)
                Toggle("状态栏显示实时网速", isOn: $model.menuBarShowSpeed)
                Button("状态栏仅显示图标") { model.useMenuBarIconOnly() }
                    .disabled(model.menuBarIconOnly)
                Picker("状态刷新间隔", selection: $model.refreshInterval) {
                    Text("1 秒").tag(1.0)
                    Text("1.2 秒").tag(1.2)
                    Text("2 秒").tag(2.0)
                    Text("5 秒").tag(5.0)
                    Text("10 秒").tag(10.0)
                }
                Picker("默认日志行数", selection: $model.logLines) {
                    Text("50").tag(50)
                    Text("100").tag(100)
                    Text("200").tag(200)
                    Text("300").tag(300)
                }
            }

            Section("安全") {
                Text("Core Secret 使用 macOS Keychain 保存。服务器 Profile 不包含 Secret。原生 URLSession 不受浏览器 CORS 限制，同时保留系统 TLS 证书验证。")
                    .foregroundStyle(.secondary)
            }

            Section("版本") {
                LabeledContent("App", value: "v" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "--"))
                LabeledContent("API baseline", value: "Mihomo Core 管理面板 v4.0.0")
                LabeledContent("Architecture", value: "arm64 only")
                LabeledContent("Minimum macOS", value: "14.0")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 12)
    }
}
