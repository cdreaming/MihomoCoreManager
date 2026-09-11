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
<<<<<<< HEAD
    @Published var proxyMode: MihomoRunMode?
    @Published var proxies: [MihomoProxy] = []
    @Published var proxyGroupOrder: [String] = []
    @Published var proxyDelayResults: [String: Int] = [:]
=======
>>>>>>> parent of 7d39e5c (v1.2.3)
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
    private var secretCache: [UUID: String] = [:]
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
<<<<<<< HEAD
        proxyMode = nil
        proxies = []
        proxyGroupOrder = []
        proxyDelayResults = [:]
=======
>>>>>>> parent of 7d39e5c (v1.2.3)
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
        await busyOperation(.core(action)) {
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

<<<<<<< HEAD
    func fetchProxies() async {
        guard let profile = selectedProfile else { return }
        let profileID = profile.id
        await busyOperation(.fetchProxies) {
            do {
                let values = try await api.proxies(profile: profile, secret: currentControllerSecret)
                let mode = try? await api.proxyMode(profile: profile, secret: currentControllerSecret)
                guard selectedProfileID == profileID else { return }

                if let mode { proxyMode = mode }
                proxies = values

                // Mihomo `/group` ranges a Go map and is intentionally not used
                // for "默认" ordering. GLOBAL.all retains config.yaml order.
                proxyGroupOrder = values.first(where: { $0.name == "GLOBAL" })?.all ?? []
                proxiesLoadedFor = profileID
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
        await busyOperation(.selectProxy(group: groupName, proxy: proxyName)) {
            try await api.selectProxy(proxyName, in: groupName, profile: profile, secret: currentControllerSecret)
            guard selectedProfileID == profileID else { return }

            applyLocalProxySelection(proxyName, in: groupName)

            do {
                let refreshed = try await api.proxies(profile: profile, secret: currentControllerSecret)
                guard selectedProfileID == profileID else { return }
                proxies = refreshed
                proxiesLoadedFor = profileID
                show("代理组“\(groupName)”已切换到“\(proxyName)”")
            } catch {
                if isTransientControllerError(error) {
                    proxiesLoadedFor = profileID
                    show("代理组“\(groupName)”已切换到“\(proxyName)”；Controller 随后暂时断开，已保留当前选择。", error: true)
                    return
                }
                throw error
            }
        }
    }

    func testProxyGroup(_ groupName: String) async {
        guard let profile = selectedProfile,
              let group = proxies.first(where: { $0.name == groupName && $0.isGroup }) else { return }
        let profileID = profile.id
        await busyOperation(.testProxyGroup(groupName)) {
            let results = try await api.testProxyGroup(
                group,
                profile: profile,
                secret: currentControllerSecret
            )
            let refreshed = try? await api.proxies(profile: profile, secret: currentControllerSecret)
            guard selectedProfileID == profileID else { return }
            for (name, delay) in results {
                proxyDelayResults[name] = delay
                let resolved = resolvedProxyName(name)
                if resolved != name {
                    proxyDelayResults[resolved] = delay
                }
            }
            if let refreshed {
                proxies = refreshed
            }
            proxiesLoadedFor = profileID
            show("代理组“\(groupName)”测速完成，共 \(results.count) 个结果")
        }
    }

    func resolvedProxyName(_ proxyName: String) -> String {
        guard !proxyName.isEmpty else { return proxyName }
        let byName = Dictionary(uniqueKeysWithValues: proxies.map { ($0.name, $0) })
        var current = proxyName
        var visited = Set<String>()

        while let proxy = byName[current],
              let next = proxy.now,
              !next.isEmpty,
              next != current {
            if visited.contains(current) { break }
            visited.insert(current)
            guard byName[next] != nil else { break }
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
            guard let proxy = proxies.first(where: { $0.name == name }) else { continue }
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
            guard let proxy = proxies.first(where: { $0.name == name }) else { continue }

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

=======
>>>>>>> parent of 7d39e5c (v1.2.3)
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

    private func applyLocalProxySelection(_ proxyName: String, in groupName: String) {
        proxies = proxies.map { proxy in
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
                let seconds = max(1, self.refreshInterval)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }
}
