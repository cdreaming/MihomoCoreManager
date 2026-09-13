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
        effectiveSystemdSSHTarget(for: self) != nil
    }

    var effectiveSystemdSSHPort: Int {
        guard let value = systemdSSHPort, (1...65_535).contains(value) else { return 22 }
        return value
    }
}

/// Infer a transport only when the user omitted the scheme.  v4.0.1 exposes
/// the three HTTP surfaces in two very different ways: private/LAN addresses
/// are normally plain HTTP, while the documented public domains are HTTPS.
/// Explicit schemes always win and business ports are never guessed.
private func endpointWithInferredScheme(_ raw: String) -> String {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !value.contains("://") else { return value }
    let probe = URLComponents(string: "http://" + value)
    let useHTTP = probe?.host.map(isLANHost) ?? false
    return (useHTTP ? "http://" : "https://") + value
}

/// Accept a pasted MetaCubeXD/UI URL such as `http://host:9090/ui/`, but store
/// the Mihomo Controller API root. Reverse-proxy prefixes are preserved, while
/// a case-insensitive standalone `ui` segment and everything after it are
/// removed.  Known Controller API endpoint suffixes are also stripped so
/// pasting `/version`, `/connections` or `/configs` cannot produce duplicated
/// paths such as `/version/version` later.
///
/// Ports are never guessed or auto-added. In particular, `:9090` is preserved
/// only when the user/deployment result explicitly contains it.
func normalizedControllerURL(_ raw: String) -> String {
    let value = endpointWithInferredScheme(raw)
    guard !value.isEmpty else { return "" }
    guard var components = URLComponents(string: value), components.host != nil else { return value }

    var segments = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    if let uiIndex = segments.firstIndex(where: { $0.caseInsensitiveCompare("ui") == .orderedSame }) {
        segments = Array(segments[..<uiIndex])
    } else {
        let lower = segments.map { $0.lowercased() }
        let suffixes: [[String]] = [
            ["providers", "proxies"],
            ["connections"], ["configs"], ["restart"], ["version"],
            ["traffic"], ["memory"], ["proxies"], ["group"]
        ]
        if let suffix = suffixes.first(where: { lower.count >= $0.count && Array(lower.suffix($0.count)) == $0 }) {
            segments.removeLast(suffix.count)
        }
    }
    components.path = segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
    components.query = nil
    components.fragment = nil
    guard var result = components.url?.absoluteString else { return value }
    if components.path.isEmpty, result.hasSuffix("/") { result.removeLast() }
    return result
}

/// Normalize a v4.x management-panel URL pasted from deployment output.
/// Known API/health suffixes are removed but an intentional reverse-proxy prefix
/// is kept, e.g. `/mihomo/api/status` -> `/mihomo`. No panel port is invented;
/// `:29090` must be present in the value if that is how the panel is exposed.
func normalizedManagementURL(_ raw: String) -> String {
    let value = endpointWithInferredScheme(raw)
    guard !value.isEmpty else { return "" }
    guard var components = URLComponents(string: value), components.host != nil else { return value }

    var segments = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    let lower = segments.map { $0.lowercased() }
    let suffixes: [[String]] = [
        ["api", "project-update", "check"],
        ["api", "project-update", "apply"],
        ["api", "project-update", "log"],
        ["api", "subscriptions"],
        ["api", "status"],
        ["api", "action"],
        ["api", "logs"],
        ["api", "login"],
        ["api", "logout"],
        ["healthz"],
        ["api"]
    ]
    if let suffix = suffixes.first(where: { lower.count >= $0.count && Array(lower.suffix($0.count)) == $0 }) {
        segments.removeLast(suffix.count)
    }
    components.path = segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
    components.query = nil
    components.fragment = nil
    guard var result = components.url?.absoluteString else { return value }
    if components.path.isEmpty, result.hasSuffix("/") { result.removeLast() }
    return result
}

/// MetaCubeXD is a standalone web surface, so its path (including `/setup` or
/// a reverse-proxy prefix) is intentional and must not be rewritten. We only
/// infer an omitted scheme and preserve the explicit port/query/fragment.
func normalizedMetaCubeXDURL(_ raw: String) -> String {
    let value = endpointWithInferredScheme(raw)
    guard !value.isEmpty else { return "" }
    guard let components = URLComponents(string: value), components.host != nil else { return value }
    return components.url?.absoluteString ?? value
}

private func configuredURLHost(_ raw: String) -> String? {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    if !value.contains("://") { value = "http://" + value }
    return URLComponents(string: value)?.host?.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func isPrivateIPv4(_ host: String) -> Bool {
    let octets = host.split(separator: ".").compactMap { Int($0) }
    guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
    return octets[0] == 10
        || octets[0] == 127
        || (octets[0] == 169 && octets[1] == 254)
        || (octets[0] == 172 && (16...31).contains(octets[1]))
        || (octets[0] == 192 && octets[1] == 168)
}

private func isLANHost(_ rawHost: String) -> Bool {
    let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")).lowercased()
    guard !host.isEmpty else { return false }
    if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local")
        || host.hasSuffix(".lan") || host.hasSuffix(".home.arpa") || !host.contains(".") {
        return true
    }
    if isPrivateIPv4(host) { return true }
    return host == "::1" || host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80:")
}

/// Explicit SSH target wins. Otherwise infer only from a LAN Management/Controller
/// host; public hosts are never automatically probed over SSH.
func effectiveSystemdSSHTarget(for profile: ServerProfile) -> String? {
    let explicit = (profile.systemdSSHTarget ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !explicit.isEmpty { return explicit }
    for raw in [profile.managementURL, profile.coreControllerURL] {
        guard let host = configuredURLHost(raw), isLANHost(host) else { continue }
        let lower = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        if lower == "localhost" || lower == "127.0.0.1" || lower == "::1" { continue }
        return host
    }
    return nil
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


/// Merge the management panel's richer deployment metadata into a status
/// snapshot whose primary truth still comes from Controller/systemd.  This is
/// deliberately asymmetric: Core runtime state from the primary backend wins;
/// panel-only versions/paths and otherwise-missing service details enrich it.
func statusMergingManagementMetadata(_ primary: StatusPayload, _ metadata: StatusPayload) -> StatusPayload {
    let service = ServiceStatus(
        manager: primary.service.manager ?? metadata.service.manager,
        active: primary.service.active,
        activeState: primary.service.activeState ?? metadata.service.activeState,
        subState: primary.service.subState ?? metadata.service.subState,
        enabled: primary.service.enabled ?? metadata.service.enabled,
        unitFileState: primary.service.unitFileState ?? metadata.service.unitFileState,
        pid: primary.service.pid ?? metadata.service.pid,
        unitFilePath: primary.service.unitFilePath ?? metadata.service.unitFilePath
    )

    let primaryVersions = primary.versions
    let metadataVersions = metadata.versions
    let versions = VersionsInfo(
        core: primaryVersions?.core ?? primary.version ?? metadataVersions?.core ?? metadata.version,
        managementPanel: metadataVersions?.managementPanel ?? primaryVersions?.managementPanel,
        metacubexd: metadataVersions?.metacubexd ?? primaryVersions?.metacubexd
    )

    return StatusPayload(
        ok: primary.ok,
        service: service,
        uptimeSeconds: primary.uptimeSeconds ?? metadata.uptimeSeconds,
        memoryBytes: primary.memoryBytes ?? metadata.memoryBytes,
        speed: primary.speed ?? metadata.speed,
        totals: primary.totals ?? metadata.totals,
        connections: primary.connections ?? metadata.connections,
        versions: versions,
        version: primary.version ?? metadata.version,
        management: metadata.management ?? primary.management,
        corePublicUrl: metadata.corePublicUrl ?? primary.corePublicUrl,
        controller: primary.controller ?? metadata.controller,
        metacubexd: metadata.metacubexd ?? primary.metacubexd
    )
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
        case .missingSecret: "此功能需要 Core/Management Secret；两个 Secret 任一未单独设置时会复用另一个。"
        case .missingController: "尚未配置 Mihomo Core Controller URL。可填写 API 根地址，也可粘贴 /ui/、/Ui/ 或 /version 等部署地址；程序会规范化为 API 根路径。"
        case .controllerUnauthorized: "Mihomo Controller HTTP 401：认证失败。请在“服务设置” > Mihomo Core 连接中填写 config.yaml 的 secret（Controller Secret）。"
        case .invalidResponse: "服务器返回了无法识别的响应。"
        case .server(let status, let message): "服务器错误 HTTP \(status)：\(message)"
        case .operationFailed(let message): message
        }
    }
}
