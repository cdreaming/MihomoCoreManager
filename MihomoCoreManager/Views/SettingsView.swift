import AppKit
import SwiftUI


struct DashboardSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var draft: ServerProfile?
    @State private var secret = ""
    @State private var controllerSecret = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardLayout.pageSpacing) {
                DashboardPageHeader(title: "服务设置", subtitle: "Mihomo Core 为主连接；管理面板与 MetaCubeXD 是可选扩展。")
                serverPanel
                if let draftBinding = Binding($draft) {
                    connectionPanel(profile: draftBinding)
                    corePanel(profile: draftBinding)
                    appPanel
                    footerActions
                }
            }
            .padding(.horizontal, DashboardLayout.pageHorizontalPadding)
            .padding(.top, DashboardLayout.pageTopPadding)
            .padding(.bottom, DashboardLayout.pageBottomPadding)
        }
        .task(id: loadTaskID) {
            guard model.selectedSection == .settings else { return }
            loadDraft()
        }
    }

    private var serverPanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: DashboardLayout.panelSpacing) {
                DashboardPanelHeader(title: "服务器配置", trailing: "Profile")
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
        }
    }

    @ViewBuilder
    private func connectionPanel(profile: Binding<ServerProfile>) -> some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: DashboardLayout.panelSpacing) {
                DashboardPanelHeader(title: "Mihomo Core 连接", trailing: "Primary · Controller API")
                settingRow("名称") { TextField("服务器名称", text: profile.name).textFieldStyle(DashboardTextFieldStyle()) }
                settingRow("Controller URL") { TextField("http://192.168.1.2:9090", text: profile.coreControllerURL).textContentType(.URL).textFieldStyle(DashboardTextFieldStyle()) }
                settingRow("Controller Secret") {
                    HStack(spacing: 8) {
                        SecureField("config.yaml 的 secret；留空兼容复用 Management Secret", text: $controllerSecret).textFieldStyle(DashboardTextFieldStyle())
                        Button("粘贴") { pasteControllerSecret() }.buttonStyle(DashboardActionButtonStyle()).frame(width: 76)
                        Button("清除") {
                            controllerSecret = ""
                            if let id = model.selectedProfileID { model.saveControllerSecret("", for: id) }
                        }
                        .buttonStyle(DashboardActionButtonStyle(destructive: true)).frame(width: 76)
                    }
                }
                settingRow("config.yaml path") { TextField("/etc/mihomo/config.yaml", text: profile.configPath).textFieldStyle(DashboardTextFieldStyle()) }
                toggleRow("允许不安全 HTTP", isOn: profile.allowInsecureHTTP, detail: "LAN 的 Mihomo Controller 常用 HTTP；只在可信网络启用。")
                Text("Controller URL 必须是 API 根地址，例如 http://192.168.9.202:9090。不要填写 /ui/。代码不会自动补 9090；如果不是 80/443，请显式写端口。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(DashboardPalette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func corePanel(profile: Binding<ServerProfile>) -> some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: DashboardLayout.panelSpacing) {
                DashboardPanelHeader(title: "扩展管理（可选）", trailing: "Lifecycle / Logs / Update")
                settingRow("Management URL") { TextField("可选；例如 http://192.168.1.2:29090", text: profile.managementURL).textContentType(.URL).textFieldStyle(DashboardTextFieldStyle()) }
                settingRow("Management Secret") {
                    HStack(spacing: 8) {
                        SecureField("留空表示不修改 Keychain", text: $secret).textFieldStyle(DashboardTextFieldStyle())
                        Button("粘贴") { pasteSecret() }.buttonStyle(DashboardActionButtonStyle()).frame(width: 76)
                        Button("清除") {
                            secret = ""
                            if let id = model.selectedProfileID { model.saveSecret("", for: id) }
                        }
                        .buttonStyle(DashboardActionButtonStyle(destructive: true)).frame(width: 76)
                    }
                }
                settingRow("MetaCubeXD URL") { TextField("可选", text: profile.metaCubeXDURL).textContentType(.URL).textFieldStyle(DashboardTextFieldStyle()) }
                toggleRow("项目升级时保留现有设置", isOn: profile.preserveSettingsOnUpdate, detail: "仅影响可选管理面板发起的项目升级。")
                Text("Management URL 不是 Mihomo Controller；它只用于启动/停止、订阅写入、系统日志和项目升级。仅做 Core 连接与代理切换时可以留空。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(DashboardPalette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appPanel: some View {
        DashboardPanel {
            VStack(alignment: .leading, spacing: DashboardLayout.panelSpacing) {
                DashboardPanelHeader(title: "App 与状态栏", trailing: "Display & performance")
                HStack(alignment: .top, spacing: DashboardLayout.sectionSpacing) {
                    appControlCell("显示状态栏按钮", detail: "显示或隐藏 macOS 菜单栏入口") {
                        Toggle("", isOn: $showMenuBarExtra).labelsHidden().toggleStyle(.switch)
                    }
                    appControlCell("状态栏显示图标", detail: "显示 Mihomo Core 状态栏图标") {
                        Toggle("", isOn: $model.menuBarShowIcon).labelsHidden().toggleStyle(.switch)
                    }
                }
                HStack(alignment: .top, spacing: DashboardLayout.sectionSpacing) {
                    appControlCell("状态栏显示运行状态", detail: "显示 Running / Stopped 状态") {
                        Toggle("", isOn: $model.menuBarShowStatus).labelsHidden().toggleStyle(.switch)
                    }
                    appControlCell("状态栏显示实时网速", detail: "上传 / 下载上下两行显示") {
                        Toggle("", isOn: $model.menuBarShowSpeed).labelsHidden().toggleStyle(.switch)
                    }
                }
                HStack(alignment: .top, spacing: DashboardLayout.sectionSpacing) {
                    appControlCell("状态刷新间隔", detail: "状态与流量刷新频率") {
                        Picker("", selection: $model.refreshInterval) {
                            Text("1 秒").tag(1.0); Text("1.2 秒").tag(1.2); Text("2 秒").tag(2.0); Text("5 秒").tag(5.0); Text("10 秒").tag(10.0)
                        }.labelsHidden().frame(width: 118)
                    }
                    appControlCell("默认日志行数", detail: "运行日志默认读取数量") {
                        Picker("", selection: $model.logLines) {
                            Text("50").tag(50); Text("100").tag(100); Text("200").tag(200); Text("300").tag(300)
                        }.labelsHidden().frame(width: 105)
                    }
                }
                appControlCell("状态栏快捷模式", detail: "隐藏状态和网速文字，仅保留图标") {
                    Button("仅显示图标") { model.useMenuBarIconOnly() }
                        .buttonStyle(DashboardActionButtonStyle()).frame(width: 110).disabled(model.menuBarIconOnly)
                }
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            Text("Controller Secret 与可选 Management Secret 均只保存到 macOS Keychain；Management Secret 对应 v1.3.0 的 Core Secret，Controller Secret 留空时自动复用它。")
                .font(.system(size: 11)).foregroundStyle(DashboardPalette.tertiary)
            Spacer()
            Button("测试连接") { saveDraft(); Task { await model.refreshStatus() } }
                .buttonStyle(DashboardActionButtonStyle()).frame(width: 110)
            Button("保存设置") { saveDraft() }
                .buttonStyle(DashboardActionButtonStyle(primary: true)).frame(width: 120)
        }
    }

    @ViewBuilder
    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title).font(.system(size: 12)).foregroundStyle(DashboardPalette.secondary).frame(width: 170, alignment: .leading)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 3)
    }

    @ViewBuilder
    private func toggleRow(_ title: String, isOn: Binding<Bool>, detail: String? = nil) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: detail == nil ? 0 : 3) {
                Text(title).font(.system(size: 12)).foregroundStyle(.white)
                if let detail { Text(detail).font(.system(size: 10.5)).foregroundStyle(DashboardPalette.tertiary) }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch)
        }.padding(.vertical, 3)
    }

    @ViewBuilder
    private func appControlCell<Content: View>(_ title: String, detail: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 10.5)).foregroundStyle(DashboardPalette.tertiary).lineLimit(2)
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(DashboardPalette.field.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(DashboardPalette.separator, lineWidth: 1) }
    }

    private var loadTaskID: String { "\(model.selectedProfileID?.uuidString ?? "none")|\(model.selectedSection.rawValue)" }
    private func loadDraft() {
        draft = model.selectedProfile
        if let id = model.selectedProfileID {
            secret = KeychainStore.readSecret(profileID: id)
            controllerSecret = KeychainStore.readControllerSecret(profileID: id)
        } else {
            secret = ""
            controllerSecret = ""
        }
    }
    private func saveDraft() {
        guard let draft else { return }
        model.updateProfile(draft)
        if !secret.isEmpty { model.saveSecret(secret, for: draft.id) }
        if !controllerSecret.isEmpty { model.saveControllerSecret(controllerSecret, for: draft.id) }
        model.show("设置已保存")
    }
    private func pasteSecret() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            model.show("剪贴板中没有可粘贴的文本。", error: true); return
        }
        secret = value.trimmingCharacters(in: .newlines)
    }

    private func pasteControllerSecret() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            model.show("剪贴板中没有可粘贴的文本。", error: true); return
        }
        controllerSecret = value.trimmingCharacters(in: .newlines)
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
    @State private var controllerSecret = ""

    var body: some View {
        Form {
            Section("Mihomo Core 连接") {
                LabeledContent("名称") {
                    TextField("服务器名称", text: $profile.name)
                        .frame(minWidth: 300)
                }
                LabeledContent("Controller URL") {
                    TextField("http://192.168.1.2:9090", text: $profile.coreControllerURL)
                        .textContentType(.URL)
                        .frame(minWidth: 300)
                }
                LabeledContent("Controller Secret") {
                    HStack(spacing: 6) {
                        SecureField("config.yaml 的 secret；留空兼容复用 Management Secret", text: $controllerSecret)
                            .frame(minWidth: 230)
                        Button { pasteControllerSecret() } label: { Image(systemName: "doc.on.clipboard") }
                            .help("从剪贴板粘贴 config.yaml 的 secret")
                        Button("保存") { model.saveControllerSecret(controllerSecret, for: profile.id) }
                    }
                }
                HStack {
                    Text("API 根地址不要带 /ui/；端口不会自动补，非 80/443 时请显式填写（Mihomo 常见为 9090）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清除 Controller Secret", role: .destructive) {
                        controllerSecret = ""
                        model.saveControllerSecret("", for: profile.id)
                    }
                }
                LabeledContent("config.yaml path") {
                    TextField("/etc/mihomo/config.yaml", text: $profile.configPath)
                        .frame(minWidth: 300)
                }
                Toggle("允许不安全 HTTP", isOn: $profile.allowInsecureHTTP)
            }

            Section("扩展管理（可选）") {
                LabeledContent("Management URL") {
                    TextField("可选；仅高级功能", text: $profile.managementURL)
                        .textContentType(.URL)
                        .frame(minWidth: 300)
                }
                LabeledContent("Management Secret") {
                    HStack(spacing: 6) {
                        SecureField("Management Secret", text: $secret)
                            .frame(minWidth: 230)
                        Button { pasteSecret() } label: { Image(systemName: "doc.on.clipboard") }
                            .help("从剪贴板粘贴 Management Secret")
                        Button("保存") { model.saveSecret(secret, for: profile.id) }
                    }
                }
                HStack {
                    Text("只用于 Core 启停、订阅写入、系统日志与项目升级；基础 Core 连接不依赖它。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清除 Management Secret", role: .destructive) {
                        secret = ""
                        model.saveSecret("", for: profile.id)
                    }
                }
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
        .task(id: profile.id) {
            secret = KeychainStore.readSecret(profileID: profile.id)
            controllerSecret = KeychainStore.readControllerSecret(profileID: profile.id)
        }
    }

    private func pasteSecret() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            model.show("剪贴板中没有可粘贴的文本。", error: true)
            return
        }
        secret = value.trimmingCharacters(in: .newlines)
    }

    private func pasteControllerSecret() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            model.show("剪贴板中没有可粘贴的文本。", error: true)
            return
        }
        controllerSecret = value.trimmingCharacters(in: .newlines)
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
                Text("Controller Secret 对应 Mihomo config.yaml 的 secret；可选 Management Secret 仅用于扩展管理功能。两者均使用 macOS Keychain；Controller Secret 留空时保留 v1.3.0 的兼容复用行为。Controller URL 的端口不会自动补。原生 URLSession 不受浏览器 CORS 限制，同时保留系统 TLS 证书验证。")
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
