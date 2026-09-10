import Foundation

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case core
    case subscriptions
    case logs
    case updates
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "概览"
        case .core: "Core 控制"
        case .subscriptions: "订阅管理"
        case .logs: "运行日志"
        case .updates: "项目升级"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .core: "bolt.horizontal.circle"
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
            allowInsecureHTTP: false,
            preserveSettingsOnUpdate: true
        )
    }

    static func blank() -> ServerProfile {
        ServerProfile(
            id: UUID(),
            name: "新服务器",
            managementURL: "https://",
            coreControllerURL: "",
            configPath: "/etc/mihomo/config.yaml",
            metaCubeXDURL: "",
            allowInsecureHTTP: false,
            preserveSettingsOnUpdate: true
        )
    }
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
    case missingSecret
    case invalidResponse
    case server(status: Int, message: String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value): "无效 URL：\(value)"
        case .insecureHTTPDisabled: "该服务器未允许明文 HTTP。请在设置中启用“允许不安全 HTTP”，或改用 HTTPS。"
        case .missingSecret: "尚未为当前服务器配置 Mihomo Core Secret。"
        case .invalidResponse: "服务器返回了无法识别的响应。"
        case .server(let status, let message): "服务器错误 HTTP \(status)：\(message)"
        case .operationFailed(let message): message
        }
    }
}
