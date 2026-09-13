import AppKit
import Combine
import Foundation

struct LiveStatusSnapshot {
    var status: StatusPayload?
    var effectiveSpeed: SpeedInfo?
    var trafficSamples: [TrafficSample] = []
}

@MainActor
final class LiveStatusStore: ObservableObject {
    @Published private(set) var snapshot = LiveStatusSnapshot()
    private var lastSuccessfulStatusAt: Date?
    private var lastTotals: (up: Int64, down: Int64, at: Date)?

    var status: StatusPayload? { snapshot.status }
    var effectiveSpeed: SpeedInfo? { snapshot.effectiveSpeed ?? snapshot.status?.speed }
    var trafficSamples: [TrafficSample] { snapshot.trafficSamples }

    func reset() {
        lastSuccessfulStatusAt = nil
        lastTotals = nil
        snapshot = LiveStatusSnapshot()
    }

    func apply(_ newStatus: StatusPayload) {
        let now = Date()
        var speed = newStatus.speed
        if speed == nil,
           let up = newStatus.totals?.up,
           let down = newStatus.totals?.down,
           let previous = lastTotals {
            let elapsed = now.timeIntervalSince(previous.at)
            if elapsed > 0.15 {
                speed = SpeedInfo(
                    up: max(0, Double(up - previous.up) / elapsed),
                    down: max(0, Double(down - previous.down) / elapsed)
                )
            }
        }
        if let up = newStatus.totals?.up, let down = newStatus.totals?.down {
            lastTotals = (up, down, now)
        }

        var samples = snapshot.trafficSamples
        samples.append(
            TrafficSample(
                date: now,
                upload: speed?.up ?? 0,
                download: speed?.down ?? 0
            )
        )
        if samples.count > 80 {
            samples.removeFirst(samples.count - 80)
        }
        lastSuccessfulStatusAt = now
        snapshot = LiveStatusSnapshot(status: newStatus, effectiveSpeed: speed, trafficSamples: samples)
    }

    func markUnavailableIfStale(grace: TimeInterval = 5) {
        guard let lastSuccessfulStatusAt,
              Date().timeIntervalSince(lastSuccessfulStatusAt) > grace,
              snapshot.status != nil else { return }
        // Preserve chart history but stop presenting an indefinitely stale
        // Running/Stopped state after a sustained telemetry outage.
        snapshot = LiveStatusSnapshot(status: nil, effectiveSpeed: nil, trafficSamples: snapshot.trafficSamples)
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [ServerProfile]
    @Published var selectedProfileID: UUID?
    @Published var selectedSection: SidebarSection = .overview
    @Published var proxyMode: MihomoRunMode?
    @Published var proxies: [MihomoProxy] = [] {
        didSet {
            proxyByNameCache = proxies.reduce(into: [:]) { result, proxy in
                result[proxy.name] = proxy
            }
        }
    }
    @Published var proxyGroupOrder: [String] = []
    @Published var proxyDelayResults: [String: Int] = [:]
    @Published var subscriptions: [String: String] = [:]
    @Published var logs: String = ""
    @Published var updateInfo: ProjectUpdateInfo?
    @Published var updateLogs: String = ""
    @Published var updateRunning = false
    @Published private(set) var isBusy = false
    @Published private(set) var activeOperation: AppOperation?
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
    private var statusRefreshes: Set<UUID> = []
    private var statusFailureCount = 0
    private var proxyBackgroundLoads: Set<UUID> = []
    private var proxyReconcileTasks: [String: Task<Void, Never>] = [:]
    private var proxyReconcileTokens: [String: UUID] = [:]
    private var proxyByNameCache: [String: MihomoProxy] = [:]
    private var secretCache: [UUID: String] = [:]
    private var controllerSecretCache: [UUID: String] = [:]
    private var proxiesLoadedFor: UUID?
    private var subscriptionsLoadedFor: UUID?
    private var logsLoadedFor: UUID?
    private var noticeDismissTask: Task<Void, Never>?

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

    var currentControllerSecret: String {
        guard let id = selectedProfileID else { return "" }
        if let cached = controllerSecretCache[id], !cached.isEmpty { return cached }
        let controllerSecret = KeychainStore.readControllerSecret(profileID: id)
        controllerSecretCache[id] = controllerSecret
        return controllerSecret.isEmpty ? currentSecret : controllerSecret
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
            parts.append("↑ \(menuRate(live.effectiveSpeed?.up))")
            parts.append("↓ \(menuRate(live.effectiveSpeed?.down))")
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

    func menuBarRateParts(_ raw: Double?) -> (value: String, unit: String) {
        var value = max(0, raw ?? 0)
        let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        // Keep the numeric field within four monospaced cells. Sub-10 values use
        // one decimal after unit conversion; all other values are integers.
        // Because the scaled value is always below 1024, the result is at most
        // four characters (for example 9.8, 53, 999 or 1023).
        let number: String
        if unitIndex > 0, value < 10 {
            number = String(format: "%.1f", value)
        } else {
            number = String(format: "%.0f", value)
        }
        return (number, units[unitIndex])
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
        statusFailureCount = 0
        proxyMode = nil
        proxies = []
        proxyGroupOrder = []
        proxyDelayResults = [:]
        subscriptions = [:]
        logs = ""
        updateInfo = nil
        updateLogs = ""
        proxiesLoadedFor = nil
        subscriptionsLoadedFor = nil
        logsLoadedFor = nil
        proxyReconcileTasks.values.forEach { $0.cancel() }
        proxyReconcileTasks.removeAll()
        proxyReconcileTokens.removeAll()
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
        KeychainStore.deleteControllerSecret(profileID: id)
        secretCache.removeValue(forKey: id)
        controllerSecretCache.removeValue(forKey: id)
        profiles.removeAll { $0.id == id }
        persistProfiles()
        if selectedProfileID == id, let first = profiles.first {
            selectProfile(first.id)
        }
    }

    func updateProfile(_ profile: ServerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var normalized = profile
        normalized.managementURL = normalizedManagementURL(normalized.managementURL)
        normalized.coreControllerURL = normalizedControllerURL(normalized.coreControllerURL)
        normalized.metaCubeXDURL = normalized.metaCubeXDURL.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.systemdSSHTarget = normalized.systemdSSHTarget?.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.systemdIdentityFile = normalized.systemdIdentityFile?.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasSystemdServiceEndpoint {
            normalized.systemdSSHPort = normalized.effectiveSystemdSSHPort
        }
        profiles[index] = normalized
        persistProfiles()
    }

    var managementFeaturesAvailable: Bool {
        guard let profile = selectedProfile else { return false }
        return profile.hasManagementEndpoint && !currentSecret.isEmpty
    }

    var systemdFeaturesAvailable: Bool {
        selectedProfile?.hasSystemdServiceEndpoint == true
    }

    var coreLifecycleAvailable: Bool {
        systemdFeaturesAvailable || managementFeaturesAvailable
    }

    var coreRestartAvailable: Bool {
        guard let profile = selectedProfile else { return false }
        return profile.hasControllerEndpoint || systemdFeaturesAvailable || managementFeaturesAvailable
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
            show(secret.isEmpty ? "已清除 Management Secret" : "Management Secret 已保存到 Keychain")
            if selectedProfileID == id { Task { await refreshStatus(silent: true) } }
        } catch {
            show("Keychain 写入失败：\(error.localizedDescription)", error: true)
        }
    }

    func saveControllerSecret(_ secret: String, for id: UUID) {
        do {
            try KeychainStore.writeControllerSecret(secret, profileID: id)
            controllerSecretCache[id] = secret
            show(secret.isEmpty ? "已清除 Controller Secret；未单独设置时将兼容复用 Management Secret" : "Controller Secret 已保存到 Keychain")
            if selectedProfileID == id {
                proxiesLoadedFor = nil
            }
        } catch {
            show("Controller Secret 写入 Keychain 失败：\(error.localizedDescription)", error: true)
        }
    }

    func refreshStatus(silent: Bool = false) async {
        guard (!isBusy || silent), let profile = selectedProfile else { return }
        let profileID = profile.id
        guard !statusRefreshes.contains(profileID) else { return }
        let secret = currentSecret
        statusRefreshes.insert(profileID)
        defer { statusRefreshes.remove(profileID) }

        do {
            let newStatus = try await api.status(
                profile: profile,
                managementSecret: secret,
                controllerSecret: currentControllerSecret
            )
            guard selectedProfileID == profileID else { return }
            statusFailureCount = 0
            live.apply(newStatus)
        } catch {
            guard selectedProfileID == profileID else { return }
            statusFailureCount = min(statusFailureCount + 1, 8)
            live.markUnavailableIfStale()
            if !silent { show(error.localizedDescription, error: true) }
        }
    }

    func ensureProxiesLoaded() async {
        guard let id = selectedProfileID, proxiesLoadedFor != id, !proxyBackgroundLoads.contains(id) else { return }
        // Track per profile rather than with one global flag: switching servers
        // should never wait for a slow request that belongs to the old server.
        proxyBackgroundLoads.insert(id)
        defer { proxyBackgroundLoads.remove(id) }

        // Let the popover/window finish its first layout pass before starting the
        // Controller request. This keeps opening animations responsive without
        // introducing the previous noticeable 90 ms delay.
        try? await Task.sleep(nanoseconds: 35_000_000)
        guard !Task.isCancelled, selectedProfileID == id, proxiesLoadedFor != id else { return }
        await fetchProxiesInBackground(for: id)
    }

    func refreshProxiesForMenuBar() async {
        guard let id = selectedProfileID else { return }

        // Opening the MenuBarExtra can overlap the first proxy-page/background
        // load. Older builds simply returned in that case, which left the native
        // GitHub/.pkg menu with group names but no `now` suffix. Wait briefly for
        // that single-flight load to finish, then take an explicit fresh snapshot.
        var waitCount = 0
        while proxyBackgroundLoads.contains(id), waitCount < 40 {
            try? await Task.sleep(nanoseconds: 25_000_000)
            guard !Task.isCancelled, selectedProfileID == id else { return }
            waitCount += 1
        }
        guard !proxyBackgroundLoads.contains(id), selectedProfileID == id else { return }

        proxyBackgroundLoads.insert(id)
        defer { proxyBackgroundLoads.remove(id) }

        // Unlike ensureProxiesLoaded(), this intentionally refreshes an existing
        // snapshot whenever the native status window is presented. The Controller's
        // `now` value can change outside this App and must stay visible in the title.
        await fetchProxiesInBackground(for: id)
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
        await busyOperation(.core(action)) {
            let message: String
            if action == .reload {
                message = try await api.reloadConfiguredPath(
                    profile: profile,
                    managementSecret: currentSecret,
                    controllerSecret: currentControllerSecret
                )
            } else if action == .restart {
                message = try await api.restartCore(
                    profile: profile,
                    managementSecret: currentSecret,
                    controllerSecret: currentControllerSecret
                )
            } else {
                message = try await api.action(action, profile: profile, secret: currentSecret)
            }
            show(message)
            try? await Task.sleep(nanoseconds: 250_000_000)
            await refreshStatus(silent: true)
        }
    }

    func fetchProxies() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        let controllerSecret = currentControllerSecret
        await busyOperation(.fetchProxies) {
            do {
                let snapshot = try await proxySnapshot(profile: profile, secret: controllerSecret)
                guard selectedProfileID == profileID else { return }
                applyProxySnapshot(snapshot, profileID: profileID)
            } catch {
                guard selectedProfileID == profileID else { return }
                if isTransientControllerError(error), !proxies.isEmpty {
                    proxiesLoadedFor = profileID
                    show("Controller 暂时不可达，已保留最近一次代理与延时数据。", error: true)
                    return
                }
                throw error
            }
        }
    }

    private func fetchProxiesInBackground(for profileID: UUID) async {
        guard let profile = selectedProfile, profile.id == profileID else { return }
        let controllerSecret = currentControllerSecret
        do {
            let snapshot = try await proxySnapshot(profile: profile, secret: controllerSecret)
            guard selectedProfileID == profileID else { return }
            applyProxySnapshot(snapshot, profileID: profileID)
        } catch {
            // Opening the menu bar or a page should never make the whole app look
            // busy or surface a transient tunnel error. Keep any last-good data;
            // an explicit Refresh still reports actionable failures to the user.
            if isTransientControllerError(error), !proxies.isEmpty {
                proxiesLoadedFor = profileID
            }
        }
    }

    private func proxySnapshot(
        profile: ServerProfile,
        secret: String
    ) async throws -> (values: [MihomoProxy], mode: MihomoRunMode?) {
        // These are independent GETs. Running them concurrently removes one
        // network round trip from both the proxy page and status-menu warm-up.
        async let valuesTask = api.proxies(profile: profile, secret: secret)
        async let modeTask = api.proxyMode(profile: profile, secret: secret)
        let values = try await valuesTask
        let mode = try? await modeTask
        return (values, mode)
    }

    private func applyProxySnapshot(
        _ snapshot: (values: [MihomoProxy], mode: MihomoRunMode?),
        profileID: UUID
    ) {
        if let mode = snapshot.mode { proxyMode = mode }
        proxies = snapshot.values

        // Mihomo `/group` ranges a Go map and is intentionally not used
        // for "默认" ordering. GLOBAL.all retains config.yaml order.
        proxyGroupOrder = snapshot.values.first(where: { $0.name == "GLOBAL" })?.all ?? []
        proxiesLoadedFor = profileID
    }

    func setProxyMode(_ mode: MihomoRunMode) async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation(.setProxyMode(mode)) {
            try await api.setProxyMode(mode, profile: profile, secret: currentControllerSecret)
            guard selectedProfileID == profileID else { return }
            proxyMode = mode
            proxiesLoadedFor = profileID
            show("运行模式已切换为\(mode.title)")
        }
    }

    func selectProxy(_ proxyName: String, in groupName: String) async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        let controllerSecret = currentControllerSecret
        await busyOperation(.selectProxy(group: groupName, proxy: proxyName)) {
            try await api.selectProxy(proxyName, in: groupName, profile: profile, secret: controllerSecret)
            guard selectedProfileID == profileID else { return }

            // A successful PUT is authoritative for the interaction. Update the
            // menu/page immediately, release the busy state, then reconcile the
            // rest of the proxy snapshot asynchronously. This avoids making every
            // selection wait for another full /proxies + providers round trip.
            applyLocalProxySelection(proxyName, in: groupName)
            proxiesLoadedFor = profileID
            show("代理组“\(groupName)”已切换到“\(proxyName)”")
            scheduleProxySelectionReconcile(
                proxyName,
                in: groupName,
                profile: profile,
                profileID: profileID,
                secret: controllerSecret
            )
        }
    }

    func testProxyGroup(_ groupName: String) async {
        guard let profile = selectedProfile,
              let group = proxyByNameCache[groupName], group.isGroup else { return }
        let profileID = profile.id
        let controllerSecret = currentControllerSecret
        await busyOperation(.testProxyGroup(groupName)) {
            let results = try await api.testProxyGroup(
                group,
                profile: profile,
                secret: controllerSecret
            )
            guard selectedProfileID == profileID else { return }
            for (name, delay) in results {
                proxyDelayResults[name] = delay
                let resolved = resolvedProxyName(name)
                if resolved != name {
                    proxyDelayResults[resolved] = delay
                }
            }
            // Group-delay already returns every displayed result. Avoid a second
            // full proxy fetch on the critical path; the normal snapshot refresh
            // will reconcile health/history later.
            proxiesLoadedFor = profileID
            show("代理组“\(groupName)”测速完成，共 \(results.count) 个结果")
        }
    }

    func resolvedProxyName(_ proxyName: String) -> String {
        guard !proxyName.isEmpty else { return proxyName }
        var current = proxyName
        var visited = Set<String>()

        while let proxy = proxyByNameCache[current],
              let next = proxy.now,
              !next.isEmpty,
              next != current {
            if visited.contains(current) { break }
            visited.insert(current)
            guard proxyByNameCache[next] != nil else { break }
            current = next
        }
        return current
    }

    private func latestDelay(_ history: [MihomoProxyDelaySample]) -> Int? {
        history.last?.delay
    }

    private func positiveDelay(_ delay: Int?) -> Int? {
        guard let delay, delay > 0 else { return nil }
        return delay
    }

    private func positiveLatencyCandidates(
        for proxy: MihomoProxy,
        preferredTestURL: String?
    ) -> [Int] {
        var values: [Int] = []

        if let preferredTestURL,
           let delay = positiveDelay(proxy.extra[preferredTestURL]?.history.last?.delay) {
            values.append(delay)
        }

        if let delay = positiveDelay(proxy.latestDelay) {
            values.append(delay)
        }

        for extra in proxy.extra.values {
            if let delay = positiveDelay(extra.history.last?.delay) {
                values.append(delay)
            }
        }
        return values
    }

    func effectiveProxyDelay(_ proxyName: String, preferredTestURL: String? = nil) -> Int? {
        let resolvedName = resolvedProxyName(proxyName)
        let names = resolvedName == proxyName ? [proxyName] : [resolvedName, proxyName]

        // Match MetaCubeXD semantics: 0 means NOT_CONNECTED / no successful
        // measurement for that URL. A zero must never hide a positive reading
        // already available under another test URL.
        for name in names {
            if let delay = positiveDelay(proxyDelayResults[name]) {
                return delay
            }
        }

        for name in names {
            guard let proxy = proxyByNameCache[name] else { continue }
            if let delay = positiveLatencyCandidates(for: proxy, preferredTestURL: preferredTestURL).first {
                return delay
            }
        }

        // Nothing succeeded. Preserve a known 0 so callers can render "超时";
        // otherwise return nil for completely unmeasured nodes.
        for name in names {
            if let tested = proxyDelayResults[name] {
                return tested
            }
            guard let proxy = proxyByNameCache[name] else { continue }

            if let preferredTestURL,
               let delay = proxy.extra[preferredTestURL]?.history.last?.delay {
                return delay
            }
            if let delay = latestDelay(proxy.history) {
                return delay
            }
            for extra in proxy.extra.values {
                if let delay = extra.history.last?.delay {
                    return delay
                }
            }
        }
        return nil
    }

    var proxyGroupsInDefaultOrder: [MihomoProxy] {
        let visible = proxies.filter { $0.isGroup && $0.hidden != true }
        guard !proxyGroupOrder.isEmpty else { return visible }

        let positions = Dictionary(uniqueKeysWithValues: proxyGroupOrder.enumerated().map { ($0.element, $0.offset) })
        return visible.sorted { lhs, rhs in
            // GLOBAL is synthetic (not a proxy-groups entry in config.yaml).
            // Keep configured groups in exact config order and place GLOBAL
            // after them instead of letting it scramble the list.
            if lhs.name == "GLOBAL", rhs.name != "GLOBAL" { return false }
            if rhs.name == "GLOBAL", lhs.name != "GLOBAL" { return true }

            let l = positions[lhs.name] ?? Int.max
            let r = positions[rhs.name] ?? Int.max
            if l != r { return l < r }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func fetchSubscriptions() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation(.fetchSubscriptions) {
            let values = try await api.subscriptions(profile: profile, secret: currentSecret)
            guard selectedProfileID == profileID else { return }
            subscriptions = values
            subscriptionsLoadedFor = profileID
        }
    }

    func saveSubscriptions() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation(.saveSubscriptions) {
            let message = try await api.saveSubscriptions(subscriptions, profile: profile, secret: currentSecret)
            subscriptionsLoadedFor = profileID
            show(message)
            await refreshStatus(silent: true)
        }
    }

    func fetchLogs() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation(.fetchLogs) {
            let value = try await api.logs(lines: logLines, profile: profile, secret: currentSecret)
            guard selectedProfileID == profileID else { return }
            logs = value
            logsLoadedFor = profileID
        }
    }

    func checkUpdate() async {
        guard let profile = selectedProfile else { return }
        await busyOperation(.checkUpdate) {
            updateInfo = try await api.checkUpdate(profile: profile, secret: currentSecret)
            show("版本检查完成")
        }
    }

    func applyUpdate() async {
        guard let profile = selectedProfile else { return }
        await busyOperation(.applyUpdate) {
            let baseline = try? await api.updateLog(profile: profile, secret: currentSecret)
            if let baseline {
                updateLogs = baseline.logs
                updateRunning = baseline.running
            }

            if baseline?.running == true {
                show("检测到项目升级正在执行，继续等待完成。")
                try await waitForUpdateCompletion(
                    profile: profile,
                    baselineLogs: baseline?.logs ?? "",
                    observedActivity: true
                )
                return
            }

            let message = try await api.applyUpdate(
                preserveSettings: profile.preserveSettingsOnUpdate,
                profile: profile,
                secret: currentSecret
            )
            show(message)
            updateRunning = true
            try await waitForUpdateCompletion(
                profile: profile,
                baselineLogs: baseline?.logs ?? "",
                observedActivity: false
            )
        }
    }

    func fetchUpdateLog() async {
        guard let profile = selectedProfile else { return }
        await busyOperation(.fetchUpdateLog) { await fetchUpdateLogInternal(profile: profile) }
    }

    func openMetaCubeXD() {
        guard let url = resolvedMetaCubeXDURL else {
            show("未配置 MetaCubeXD URL，且服务器状态未返回可用地址。", error: true)
            return
        }
        NSWorkspace.shared.open(url)
    }

    func show(_ text: String, error: Bool = false) {
        noticeDismissTask?.cancel()
        noticeDismissTask = nil
        notice = AppNotice(text: text, isError: error)
        if !error && !isBusy {
            scheduleNoticeDismissIfNeeded()
        }
    }

    func dismissNotice() {
        noticeDismissTask?.cancel()
        noticeDismissTask = nil
        notice = nil
    }

    private func scheduleNoticeDismissIfNeeded(after delay: TimeInterval = 2.4) {
        guard !isBusy, let currentNotice = notice, !currentNotice.isError else { return }
        let noticeID = currentNotice.id
        noticeDismissTask?.cancel()
        noticeDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.notice?.id == noticeID, !self.isBusy else { return }
            self.notice = nil
            self.noticeDismissTask = nil
        }
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

    private func waitForUpdateCompletion(
        profile: ServerProfile,
        baselineLogs: String,
        observedActivity initiallyObservedActivity: Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(30 * 60)
        var observedActivity = initiallyObservedActivity
        var idlePollsAfterStart = 0
        var lastConnectionNoticeAt = Date.distantPast

        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 750_000_000)

            do {
                let result = try await api.updateLog(profile: profile, secret: currentSecret)
                updateLogs = result.logs
                updateRunning = result.running

                if result.running || result.logs != baselineLogs {
                    observedActivity = true
                }

                if result.running {
                    idlePollsAfterStart = 0
                    continue
                }

                if observedActivity {
                    updateRunning = false
                    if let latest = try? await api.checkUpdate(profile: profile, secret: currentSecret) {
                        updateInfo = latest
                    }
                    show("项目升级执行完成")
                    return
                }

                // A very fast update can complete between two polls without exposing running=true.
                // Require several idle confirmations after the accepted POST before considering it done.
                idlePollsAfterStart += 1
                if idlePollsAfterStart >= 4 {
                    updateRunning = false
                    if let latest = try? await api.checkUpdate(profile: profile, secret: currentSecret) {
                        updateInfo = latest
                    }
                    show("项目升级执行完成")
                    return
                }
            } catch {
                // Updating the management panel may briefly restart the remote service. Keep the
                // initiating button busy and continue polling instead of falsely reporting completion.
                observedActivity = true
                updateRunning = true
                if Date().timeIntervalSince(lastConnectionNoticeAt) > 6 {
                    lastConnectionNoticeAt = Date()
                    show("升级进行中，等待管理面板恢复连接…")
                }
            }
        }

        updateRunning = false
        throw MihomoClientError.operationFailed("等待项目升级完成超时，请检查升级日志和远端服务状态。")
    }

    func currentProxySelection(in groupName: String) -> String? {
        guard let proxy = proxyByNameCache[groupName], proxy.isGroup else { return nil }
        return proxy.now
    }

    func proxy(named name: String) -> MihomoProxy? {
        proxyByNameCache[name]
    }

    private func scheduleProxySelectionReconcile(
        _ proxyName: String,
        in groupName: String,
        profile: ServerProfile,
        profileID: UUID,
        secret: String
    ) {
        proxyReconcileTasks[groupName]?.cancel()
        let token = UUID()
        proxyReconcileTokens[groupName] = token
        proxyReconcileTasks[groupName] = Task { @MainActor [weak self] in
            // Give the Controller/tunnel a brief moment to expose the newly
            // selected `now` value. This work is intentionally off the button's
            // busy path and can be cancelled by a newer selection.
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled, let self else { return }

            defer {
                // A cancelled request can finish after a newer request for the
                // same group. Only the task that still owns this token may clear
                // the registry entry, so the newer reconcile remains cancellable.
                if self.proxyReconcileTokens[groupName] == token {
                    self.proxyReconcileTasks[groupName] = nil
                    self.proxyReconcileTokens[groupName] = nil
                }
            }

            do {
                let refreshed = try await self.api.proxies(profile: profile, secret: secret)
                guard !Task.isCancelled,
                      self.selectedProfileID == profileID,
                      self.currentProxySelection(in: groupName) == proxyName else { return }

                // A just-confirmed PUT remains authoritative for this group even
                // if the first GET is momentarily stale behind a remote tunnel.
                self.proxies = self.proxiesByApplyingSelection(proxyName, in: groupName, to: refreshed)
                self.proxyGroupOrder = refreshed.first(where: { $0.name == "GLOBAL" })?.all ?? self.proxyGroupOrder
                self.proxiesLoadedFor = profileID
            } catch {
                // The selection itself already succeeded. Reconciliation is
                // best-effort and must not turn a successful click into an error
                // notification just because the follow-up GET lost connectivity.
            }
        }
    }

    private func proxiesByApplyingSelection(
        _ proxyName: String,
        in groupName: String,
        to values: [MihomoProxy]
    ) -> [MihomoProxy] {
        values.map { proxy in
            guard proxy.name == groupName else { return proxy }
            return MihomoProxy(
                name: proxy.name,
                type: proxy.type,
                now: proxyName,
                all: proxy.all,
                history: proxy.history,
                extra: proxy.extra,
                alive: proxy.alive,
                hidden: proxy.hidden,
                udp: proxy.udp,
                xudp: proxy.xudp,
                tfo: proxy.tfo,
                testURL: proxy.testURL,
                expectedStatus: proxy.expectedStatus
            )
        }
    }

    private func applyLocalProxySelection(_ proxyName: String, in groupName: String) {
        proxies = proxiesByApplyingSelection(proxyName, in: groupName, to: proxies)
    }

    private func isTransientControllerError(_ error: Error) -> Bool {
        if let clientError = error as? MihomoClientError,
           case .server(let status, _) = clientError {
            return [502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 530].contains(status)
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func busyOperation(_ operationID: AppOperation, _ operation: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        activeOperation = operationID
        defer {
            activeOperation = nil
            isBusy = false
            scheduleNoticeDismissIfNeeded()
        }
        do { try await operation() }
        catch { show(error.localizedDescription, error: true) }
    }

    private func startPolling() {
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshStatus(silent: true)

                // Keep normal telemetry at the configured cadence, but back off
                // aggressively after repeated network/gateway failures. This is
                // especially important for Cloudflare Tunnel origins: continually
                // polling a recovering connector can prolong an otherwise brief
                // 52x/530 outage and makes the App look like it caused the tunnel.
                let base = max(1, self.refreshInterval)
                let failures = min(self.statusFailureCount, 5)
                let failureDelay = failures == 0
                    ? base
                    : min(30, max(base, 2.5 * pow(2, Double(failures - 1))))
                try? await Task.sleep(nanoseconds: UInt64(failureDelay * 1_000_000_000))
            }
        }
    }
}
