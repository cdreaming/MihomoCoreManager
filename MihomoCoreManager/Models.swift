import Foundation

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case core
    case proxies
    case subscriptions
    case logs
    case updates
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "概览"
        case .core: "Core 控制"
        case .proxies: "代理切换"
        case .subscriptions: "订阅管理"
        case .logs: "运行日志"
        case .updates: "项目升级"
        case .settings: "服务设置"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .core: "bolt.horizontal.circle"
        case .proxies: "arrow.triangle.branch"
        case .subscriptions: "arrow.triangle.2.circlepath"
        case .logs: "doc.text.magnifyingglass"
        case .updates: "arrow.down.circle"
        case .settings: "gearshape"
        }
    }
}

struct ServerProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var managementURL: String
    var coreControllerURL: String
    var configPath: String
    var metaCubeXDURL: String
    /// Optional SSH destination used to manage the server's fixed `mihomo.service` unit.
    /// Examples: `root@192.168.1.2`, `admin@mihomo.lan`, or an SSH config alias.
    /// Empty/nil keeps direct systemd management disabled and preserves v1.3.1 profiles.
    var systemdSSHTarget: String?
    /// SSH port for direct `mihomo.service` control. Nil/0 means the standard port 22.
    var systemdSSHPort: Int?
    /// Optional local private-key path. Empty/nil uses ssh-agent / ~/.ssh/config.
    var systemdIdentityFile: String?
    var allowInsecureHTTP: Bool
    var preserveSettingsOnUpdate: Bool

    static func defaultProfile() -> ServerProfile {
        ServerProfile(
            id: UUID(),
            name: "默认服务器",
            managementURL: "https://mihomo.kkr.cc",
            coreControllerURL: "https://mihomocore.kkr.cc",
            configPath: "/etc/mihomo/config.yaml",
            metaCubeXDURL: "https://metacubexd.kkr.cc",
            systemdSSHTarget: nil,
            systemdSSHPort: 22,
            systemdIdentityFile: nil,
            allowInsecureHTTP: false,
            preserveSettingsOnUpdate: true
        )
    }

    static func blank() -> ServerProfile {
        ServerProfile(
            id: UUID(),
            name: "新服务器",
            managementURL: "",
            coreControllerURL: "",
            configPath: "/etc/mihomo/config.yaml",
            metaCubeXDURL: "",
            systemdSSHTarget: nil,
            systemdSSHPort: 22,
            systemdIdentityFile: nil,
            allowInsecureHTTP: false,
            preserveSettingsOnUpdate: true
        )
    }

    var hasControllerEndpoint: Bool {
        !coreControllerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasManagementEndpoint: Bool {
        !managementURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasSystemdServiceEndpoint: Bool {
        !(systemdSSHTarget ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var effectiveSystemdSSHPort: Int {
        guard let value = systemdSSHPort, (1...65_535).contains(value) else { return 22 }
        return value
    }
}

/// Accept a pasted MetaCubeXD/UI URL such as `http://host:9090/ui/`, but store
/// the Mihomo Controller API root. The port is intentionally preserved and is
/// never guessed or auto-added: non-default ports must be entered explicitly.
func normalizedControllerURL(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return "" }
    if !value.contains("://") { value = "http://" + value }
    guard var components = URLComponents(string: value), components.host != nil else { return value }

    let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if path == "ui" || path.hasPrefix("ui/") {
        components.path = ""
    }
    components.query = nil
    components.fragment = nil
    guard var result = components.url?.absoluteString else { return value }
    if components.path.isEmpty, result.hasSuffix("/") { result.removeLast() }
    return result
}

struct APIMessage: Decodable {
    let ok: Bool
    let message: String?
}

struct StatusPayload: Decodable {
    let ok: Bool
    let service: ServiceStatus
    let uptimeSeconds: Double?
    let memoryBytes: Int64?
    let speed: SpeedInfo?
    let totals: TotalsInfo?
    let connections: Int?
    let versions: VersionsInfo?
    let version: String?
    let management: ManagementInfo?
    let corePublicUrl: String?
    let controller: String?
    let metacubexd: MetaCubeXDInfo?
}

struct ServiceStatus: Decodable {
    let manager: String?
    let active: Bool
    let activeState: String?
    let subState: String?
    let enabled: Bool?
    let unitFileState: String?
    let pid: Int?
    let unitFilePath: String?
}

struct SpeedInfo: Decodable {
    let up: Double?
    let down: Double?
}

struct TotalsInfo: Decodable {
    let up: Int64?
    let down: Int64?
}

struct VersionsInfo: Decodable {
    let core: String?
    let managementPanel: String?
    let metacubexd: String?
}

struct ManagementInfo: Decodable {
    let publicUrl: String?
    let credentialCacheDays: Int?
    let cookieAuth: Bool?
}

struct MetaCubeXDInfo: Decodable {
    let standalone: Bool?
    let coreRequiredForPage: Bool?
    let port: Int?
    let url: String?
    let settingsFile: String?
    let publicUrlSettingsFile: String?
}

struct SubscriptionsResponse: Decodable {
    let ok: Bool
    let subscriptions: [String: String]
}

struct LogsResponse: Decodable {
    let ok: Bool
    let logs: String
}

struct UpdateLogResponse: Decodable {
    let ok: Bool
    let running: Bool
    let logs: String
}

struct UpdateCheckResponse: Decodable {
    let ok: Bool
    let updates: ProjectUpdateInfo
}

struct ProjectUpdateInfo: Decodable {
    let coreCurrent: String?
    let coreLatest: String?
    let coreUpdateAvailable: Bool?
    let metacubexdCurrent: String?
    let metacubexdLatest: String?
    let metacubexdUpdateAvailable: Bool?
    let managementPanelCurrent: String?
    let managementPanelLatest: String?
    let managementPanelBundled: String?
    let managementPanelUpdateAvailable: Bool?
    let installerVersion: String?
}


enum MihomoRunMode: String, CaseIterable, Identifiable, Codable {
    case rule
    case global
    case direct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rule: "规则"
        case .global: "全局"
        case .direct: "直连"
        }
    }

    var systemImage: String {
        switch self {
        case .rule: "list.bullet.rectangle"
        case .global: "globe"
        case .direct: "arrow.right.circle"
        }
    }
}


enum ProxySortOption: String, CaseIterable, Identifiable, Hashable {
    case defaultOrder
    case delay
    case quality
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultOrder: "默认"
        case .delay: "延时"
        case .quality: "质量"
        case .name: "名字"
        }
    }

    var systemImage: String {
        switch self {
        case .defaultOrder: "line.3.horizontal"
        case .delay: "gauge.with.dots.needle.33percent"
        case .quality: "waveform.path.ecg"
        case .name: "textformat"
        }
    }
}

struct MihomoProxyDelaySample: Decodable, Hashable {
    let time: String?
    let delay: Int?
}

struct MihomoProxyDelayExtra: Decodable, Hashable {
    let alive: Bool?
    let history: [MihomoProxyDelaySample]

    private enum CodingKeys: String, CodingKey {
        case alive
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alive = try container.decodeIfPresent(Bool.self, forKey: .alive)
        history = try container.decodeIfPresent([MihomoProxyDelaySample].self, forKey: .history) ?? []
    }
}

struct MihomoProxy: Identifiable, Hashable {
    let name: String
    let type: String
    let now: String?
    let all: [String]
    let history: [MihomoProxyDelaySample]
    let extra: [String: MihomoProxyDelayExtra]
    let alive: Bool?
    let hidden: Bool?
    let udp: Bool?
    let xudp: Bool?
    let tfo: Bool?
    let testURL: String?
    let expectedStatus: String?

    var id: String { name }
    var isGroup: Bool { !all.isEmpty }
    var latestDelay: Int? { history.last?.delay }

    var isSelectableGroup: Bool {
        switch type.lowercased() {
        case "selector", "urltest", "fallback": true
        default: false
        }
    }

    init(
        name: String,
        type: String,
        now: String?,
        all: [String],
        history: [MihomoProxyDelaySample],
        extra: [String: MihomoProxyDelayExtra],
        alive: Bool?,
        hidden: Bool?,
        udp: Bool?,
        xudp: Bool?,
        tfo: Bool?,
        testURL: String?,
        expectedStatus: String?
    ) {
        self.name = name
        self.type = type
        self.now = now
        self.all = all
        self.history = history
        self.extra = extra
        self.alive = alive
        self.hidden = hidden
        self.udp = udp
        self.xudp = xudp
        self.tfo = tfo
        self.testURL = testURL
        self.expectedStatus = expectedStatus
    }
}

struct TrafficSample: Identifiable {
    let id = UUID()
    let date: Date
    let upload: Double
    let download: Double
}

enum CoreAction: String, Equatable {
    case start
    case stop
    case restart
    case reload
    case applySubscriptions = "apply_subscriptions"

    var displayName: String {
        switch self {
        case .start: "启动 Core"
        case .stop: "停止 Core"
        case .restart: "重启 Core"
        case .reload: "重载配置"
        case .applySubscriptions: "应用订阅"
        }
    }
}

enum AppOperation: Equatable {
    case core(CoreAction)
    case fetchProxies
    case setProxyMode(MihomoRunMode)
    case selectProxy(group: String, proxy: String)
    case testProxyGroup(String)
    case fetchSubscriptions
    case saveSubscriptions
    case fetchLogs
    case checkUpdate
    case applyUpdate
    case fetchUpdateLog
}

struct AppNotice: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isError: Bool
}

enum MihomoClientError: LocalizedError {
    case invalidURL(String)
    case insecureHTTPDisabled
    case missingManagement
    case missingSecret
    case missingController
    case controllerUnauthorized
    case invalidResponse
    case server(status: Int, message: String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value): "无效 URL：\(value)"
        case .insecureHTTPDisabled: "该服务器未允许明文 HTTP。请在“服务设置”中启用“允许不安全 HTTP”，或改用 HTTPS。"
        case .missingManagement: "此功能需要可选的管理面板 URL；Mihomo Core 基础连接本身不需要它。"
        case .missingSecret: "此功能需要管理面板 Secret；Controller Secret 仅用于 Mihomo Core API。"
        case .missingController: "尚未配置 Mihomo Core Controller URL。请填写 API 根地址，例如 http://192.168.1.2:9090，不要带 /ui/。"
        case .controllerUnauthorized: "Mihomo Controller HTTP 401：认证失败。请在“服务设置” > Mihomo Core 连接中填写 config.yaml 的 secret（Controller Secret）。"
        case .invalidResponse: "服务器返回了无法识别的响应。"
        case .server(let status, let message): "服务器错误 HTTP \(status)：\(message)"
        case .operationFailed(let message): message
        }
    }
}
