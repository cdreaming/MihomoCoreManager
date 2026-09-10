import AppKit
import Combine
import Foundation

struct LiveStatusSnapshot {
    var status: StatusPayload?
    var trafficSamples: [TrafficSample] = []
}

@MainActor
final class LiveStatusStore: ObservableObject {
    @Published private(set) var snapshot = LiveStatusSnapshot()

    var status: StatusPayload? { snapshot.status }
    var trafficSamples: [TrafficSample] { snapshot.trafficSamples }

    func reset() {
        snapshot = LiveStatusSnapshot()
    }

    func apply(_ newStatus: StatusPayload) {
        var samples = snapshot.trafficSamples
        samples.append(
            TrafficSample(
                date: Date(),
                upload: newStatus.speed?.up ?? 0,
                download: newStatus.speed?.down ?? 0
            )
        )
        if samples.count > 80 {
            samples.removeFirst(samples.count - 80)
        }
        snapshot = LiveStatusSnapshot(status: newStatus, trafficSamples: samples)
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [ServerProfile]
    @Published var selectedProfileID: UUID?
    @Published var selectedSection: SidebarSection = .overview
    @Published var subscriptions: [String: String] = [:]
    @Published var logs: String = ""
    @Published var updateInfo: ProjectUpdateInfo?
    @Published var updateLogs: String = ""
    @Published var updateRunning = false
    @Published var isBusy = false
    @Published var notice: AppNotice?
    @Published var menuBarShowIcon: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowIcon, forKey: Self.menuBarShowIconKey)
            ensureMenuBarVisibility()
        }
    }
    @Published var menuBarShowStatus: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowStatus, forKey: Self.menuBarShowStatusKey)
            ensureMenuBarVisibility()
        }
    }
    @Published var menuBarShowSpeed: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowSpeed, forKey: Self.menuBarShowSpeedKey)
            ensureMenuBarVisibility()
        }
    }
    @Published var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: Self.refreshIntervalKey)
        }
    }
    @Published var logLines: Int {
        didSet {
            UserDefaults.standard.set(logLines, forKey: Self.logLinesKey)
        }
    }

    let live = LiveStatusStore()

    private let store = ProfileStore()
    private let api = MihomoAPIClient()
    private var pollingTask: Task<Void, Never>?
    private var secretCache: [UUID: String] = [:]
    private var subscriptionsLoadedFor: UUID?
    private var logsLoadedFor: UUID?

    private static let selectedProfileKey = "selectedProfileID"
    private static let refreshIntervalKey = "refreshInterval"
    private static let logLinesKey = "logLines"
    private static let menuBarShowIconKey = "menuBarShowIcon"
    private static let menuBarShowStatusKey = "menuBarShowStatus"
    private static let menuBarShowSpeedKey = "menuBarShowSpeed"

    init() {
        var loaded = store.load()
        if loaded.isEmpty {
            loaded = [.defaultProfile()]
            try? store.save(loaded)
        }
        profiles = loaded

        if let raw = UserDefaults.standard.string(forKey: Self.selectedProfileKey),
           let id = UUID(uuidString: raw),
           loaded.contains(where: { $0.id == id }) {
            selectedProfileID = id
        } else {
            selectedProfileID = loaded.first?.id
        }

        let defaults = UserDefaults.standard
        menuBarShowIcon = defaults.object(forKey: Self.menuBarShowIconKey) == nil
            ? true
            : defaults.bool(forKey: Self.menuBarShowIconKey)
        menuBarShowStatus = defaults.object(forKey: Self.menuBarShowStatusKey) == nil
            ? true
            : defaults.bool(forKey: Self.menuBarShowStatusKey)
        menuBarShowSpeed = defaults.object(forKey: Self.menuBarShowSpeedKey) == nil
            ? true
            : defaults.bool(forKey: Self.menuBarShowSpeedKey)

        let storedInterval = defaults.double(forKey: Self.refreshIntervalKey)
        refreshInterval = storedInterval >= 1 ? storedInterval : 1.2
        let storedLogLines = defaults.integer(forKey: Self.logLinesKey)
        logLines = storedLogLines >= 10 ? storedLogLines : 100

        startPolling()
    }

    var status: StatusPayload? { live.status }

    var selectedProfile: ServerProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first(where: { $0.id == selectedProfileID })
    }

    var currentSecret: String {
        guard let id = selectedProfileID else { return "" }
        if let cached = secretCache[id] { return cached }
        let secret = KeychainStore.readSecret(profileID: id)
        secretCache[id] = secret
        return secret
    }

    var menuBarIconOnly: Bool {
        menuBarShowIcon && !menuBarShowStatus && !menuBarShowSpeed
    }

    var menuBarSummary: String {
        var parts: [String] = []
        if menuBarShowStatus {
            parts.append(status?.service.active == true ? "Running" : (status == nil ? "Checking" : "Stopped"))
        }
        if menuBarShowSpeed {
            parts.append("↑ \(menuRate(status?.speed?.up))")
            parts.append("↓ \(menuRate(status?.speed?.down))")
        }
        return parts.joined(separator: " · ")
    }

    func useMenuBarIconOnly() {
        menuBarShowIcon = true
        menuBarShowStatus = false
        menuBarShowSpeed = false
    }


    private func ensureMenuBarVisibility() {
        // Keep at least one visible element. Otherwise the status item can become
        // impossible to click and the user would need to reopen Settings to recover it.
        if !menuBarShowIcon && !menuBarShowStatus && !menuBarShowSpeed {
            menuBarShowIcon = true
        }
    }

    func menuRate(_ raw: Double?) -> String {
        var value = max(0, raw ?? 0)
        let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        let digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2)
        return String(format: "%.*f %@", digits, value, units[unit])
    }

    func menuRateCompact(_ raw: Double?) -> String {
        var value = max(0, raw ?? 0)
        let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        let digits = unit == 0 ? 0 : (value < 10 ? 1 : 0)
        return String(format: "%.*f %@", digits, value, units[unit])
    }

    var resolvedMetaCubeXDURL: URL? {
        guard let profile = selectedProfile else { return nil }
        let candidates = [profile.metaCubeXDURL, status?.metacubexd?.url ?? ""]
        for candidate in candidates {
            let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, let url = URL(string: value) { return url }
        }
        return nil
    }

    func selectProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileID = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.selectedProfileKey)
        live.reset()
        subscriptions = [:]
        logs = ""
        updateInfo = nil
        updateLogs = ""
        subscriptionsLoadedFor = nil
        logsLoadedFor = nil
        Task { await refreshStatus(silent: true) }
    }

    func addProfile() {
        let profile = ServerProfile.blank()
        profiles.append(profile)
        persistProfiles()
        selectProfile(profile.id)
    }

    func removeProfile(_ id: UUID) {
        guard profiles.count > 1 else {
            show("至少保留一个服务器配置。", error: true)
            return
        }
        KeychainStore.deleteSecret(profileID: id)
        secretCache.removeValue(forKey: id)
        profiles.removeAll { $0.id == id }
        persistProfiles()
        if selectedProfileID == id, let first = profiles.first {
            selectProfile(first.id)
        }
    }

    func updateProfile(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        persistProfiles()
    }

    func hasSecret(for id: UUID) -> Bool {
        if let cached = secretCache[id] { return !cached.isEmpty }
        let secret = KeychainStore.readSecret(profileID: id)
        secretCache[id] = secret
        return !secret.isEmpty
    }

    func saveSecret(_ secret: String, for id: UUID) {
        do {
            try KeychainStore.writeSecret(secret, profileID: id)
            secretCache[id] = secret
            show(secret.isEmpty ? "已清除 Core Secret" : "Core Secret 已保存到 Keychain")
            if selectedProfileID == id { Task { await refreshStatus(silent: true) } }
        } catch {
            show("Keychain 写入失败：\(error.localizedDescription)", error: true)
        }
    }

    func refreshStatus(silent: Bool = false) async {
        guard !isBusy || silent, let profile = selectedProfile else { return }
        let profileID = profile.id
        do {
            let newStatus = try await api.status(profile: profile, secret: currentSecret)
            guard selectedProfileID == profileID else { return }
            live.apply(newStatus)
        } catch {
            if !silent { show(error.localizedDescription, error: true) }
        }
    }

    func ensureSubscriptionsLoaded() async {
        guard let id = selectedProfileID, subscriptionsLoadedFor != id else { return }
        try? await Task.sleep(nanoseconds: 90_000_000)
        guard !Task.isCancelled, selectedProfileID == id else { return }
        await fetchSubscriptions()
    }

    func ensureLogsLoaded() async {
        guard let id = selectedProfileID, logsLoadedFor != id else { return }
        try? await Task.sleep(nanoseconds: 90_000_000)
        guard !Task.isCancelled, selectedProfileID == id else { return }
        await fetchLogs()
    }

    func perform(_ action: CoreAction) async {
        guard let profile = selectedProfile else { return }
        await busyOperation {
            let message: String
            if action == .reload {
                message = try await api.reloadConfiguredPath(profile: profile, secret: currentSecret)
            } else {
                message = try await api.action(action, profile: profile, secret: currentSecret)
            }
            show(message)
            try? await Task.sleep(nanoseconds: 250_000_000)
            await refreshStatus(silent: true)
        }
    }

    func fetchSubscriptions() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation {
            let values = try await api.subscriptions(profile: profile, secret: currentSecret)
            guard selectedProfileID == profileID else { return }
            subscriptions = values
            subscriptionsLoadedFor = profileID
        }
    }

    func saveSubscriptions() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation {
            let message = try await api.saveSubscriptions(subscriptions, profile: profile, secret: currentSecret)
            subscriptionsLoadedFor = profileID
            show(message)
            await refreshStatus(silent: true)
        }
    }

    func fetchLogs() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation {
            let value = try await api.logs(lines: logLines, profile: profile, secret: currentSecret)
            guard selectedProfileID == profileID else { return }
            logs = value
            logsLoadedFor = profileID
        }
    }

    func checkUpdate() async {
        guard let profile = selectedProfile else { return }
        await busyOperation {
            updateInfo = try await api.checkUpdate(profile: profile, secret: currentSecret)
            show("版本检查完成")
        }
    }

    func applyUpdate() async {
        guard let profile = selectedProfile else { return }
        await busyOperation {
            let message = try await api.applyUpdate(
                preserveSettings: profile.preserveSettingsOnUpdate,
                profile: profile,
                secret: currentSecret
            )
            show(message)
            try? await Task.sleep(nanoseconds: 600_000_000)
            await fetchUpdateLogInternal(profile: profile)
        }
    }

    func fetchUpdateLog() async {
        guard let profile = selectedProfile else { return }
        await busyOperation { await fetchUpdateLogInternal(profile: profile) }
    }

    func openMetaCubeXD() {
        guard let url = resolvedMetaCubeXDURL else {
            show("未配置 MetaCubeXD URL，且服务器状态未返回可用地址。", error: true)
            return
        }
        NSWorkspace.shared.open(url)
    }

    func show(_ text: String, error: Bool = false) {
        notice = AppNotice(text: text, isError: error)
    }

    private func fetchUpdateLogInternal(profile: ServerProfile) async {
        do {
            let result = try await api.updateLog(profile: profile, secret: currentSecret)
            updateLogs = result.logs
            updateRunning = result.running
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func persistProfiles() {
        do { try store.save(profiles) }
        catch { show("服务器配置保存失败：\(error.localizedDescription)", error: true) }
    }

    private func busyOperation(_ operation: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do { try await operation() }
        catch { show(error.localizedDescription, error: true) }
    }

    private func startPolling() {
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshStatus(silent: true)
                let seconds = max(1, self.refreshInterval)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }
}
