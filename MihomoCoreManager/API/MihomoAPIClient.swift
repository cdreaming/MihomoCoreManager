import Foundation
import Dispatch

private struct ControllerConfigResponse: Decodable {
    let mode: String?
}

private struct ControllerVersionResponse: Decodable {
    let version: String?
}

private struct ControllerConnectionSummary: Decodable {}

private struct ControllerConnectionsStatusResponse: Decodable {
    let downloadTotal: Int64?
    let uploadTotal: Int64?
    let connections: [ControllerConnectionSummary]?
    let memory: Int64?
}

private struct ControllerProxiesResponse: Decodable {
    let proxies: [String: ControllerProxyWire]
}

private struct ControllerGroupsResponse: Decodable {
    let proxies: [ControllerProxyWire]
}

private struct ControllerProvidersResponse: Decodable {
    let providers: [String: ControllerProviderWire]
}

private struct ControllerProviderWire: Decodable {
    let name: String?
    let testUrl: String?
    let proxies: [ControllerProxyWire]?
}

private struct ControllerProxyWire: Decodable {
    let name: String?
    let type: String?
    let now: String?
    let all: [String]?
    let history: [MihomoProxyDelaySample]?
    let extra: [String: MihomoProxyDelayExtra]?
    let alive: Bool?
    let hidden: Bool?
    let udp: Bool?
    let xudp: Bool?
    let tfo: Bool?
    let testUrl: String?
    let expectedStatus: String?

    init(
        name: String?,
        type: String?,
        now: String?,
        all: [String]?,
        history: [MihomoProxyDelaySample]?,
        extra: [String: MihomoProxyDelayExtra]?,
        alive: Bool?,
        hidden: Bool?,
        udp: Bool?,
        xudp: Bool?,
        tfo: Bool?,
        testUrl: String?,
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
        self.testUrl = testUrl
        self.expectedStatus = expectedStatus
    }
}

private struct ControllerErrorMessage: Decodable {
    let message: String?
}

struct MihomoAPIClient {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        // Keep credentials/cookies out of persistent storage while still reusing
        // HTTPS connections aggressively enough for 1.2 s status polling and
        // concurrent Controller reads.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()

    private struct SSHProcessResult {
        let stdout: Data
        let stderr: Data
        let exitCode: Int32
    }

    private struct RemoteRequestFailure: Error {
        let data: Data
        let status: Int
        let error: Error
    }

    private func systemdSSHTarget(profile: ServerProfile) -> String? {
        effectiveSystemdSSHTarget(for: profile)
    }

    private func systemdSSHArguments(profile: ServerProfile, command: String) throws -> [String] {
        guard let target = systemdSSHTarget(profile: profile) else {
            throw MihomoClientError.operationFailed("未显式配置 mihomo.service SSH 目标；SSH 回退未启用")
        }
        guard !target.hasPrefix("-"), target.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw MihomoClientError.operationFailed("mihomo.service SSH 目标格式无效")
        }

        var arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=4",
            "-o", "ConnectionAttempts=1",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "LogLevel=ERROR",
            "-p", String(profile.effectiveSystemdSSHPort)
        ]
        let identity = (profile.systemdIdentityFile ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !identity.isEmpty {
            arguments += ["-i", NSString(string: identity).expandingTildeInPath]
        }
        arguments += ["--", target, command]
        return arguments
    }

    private func runSSHProcess(
        profile: ServerProfile,
        command: String,
        stdin: Data = Data(),
        timeout: TimeInterval = 10
    ) async throws -> SSHProcessResult {
        let arguments = try systemdSSHArguments(profile: profile, command: command)
        return try await Task.detached(priority: .utility) { () throws -> SSHProcessResult in
            let fileManager = FileManager.default
            let directory = fileManager.temporaryDirectory
                .appendingPathComponent("MihomoManager-ssh-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: directory) }

            let stdoutURL = directory.appendingPathComponent("stdout")
            let stderrURL = directory.appendingPathComponent("stderr")
            let stdinURL = directory.appendingPathComponent("stdin")
            fileManager.createFile(atPath: stdoutURL.path, contents: nil)
            fileManager.createFile(atPath: stderrURL.path, contents: nil)
            if !stdin.isEmpty { try stdin.write(to: stdinURL, options: [.atomic]) }

            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            let stdinHandle = stdin.isEmpty ? nil : try FileHandle(forReadingFrom: stdinURL)
            defer {
                try? stdoutHandle.close()
                try? stderrHandle.close()
                try? stdinHandle?.close()
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = arguments
            process.standardInput = stdinHandle ?? FileHandle.nullDevice
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle
            let finished = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in finished.signal() }
            try process.run()
            if finished.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                _ = finished.wait(timeout: .now() + 1)
                throw MihomoClientError.operationFailed("SSH 执行超时（\(Int(timeout)) 秒）")
            }
            try? stdoutHandle.synchronize()
            try? stderrHandle.synchronize()
            return SSHProcessResult(
                stdout: (try? Data(contentsOf: stdoutURL)) ?? Data(),
                stderr: (try? Data(contentsOf: stderrURL)) ?? Data(),
                exitCode: process.terminationStatus
            )
        }.value
    }

    private func runSystemdSSH(profile: ServerProfile, command: String) async throws -> String {
        let result = try await runSSHProcess(profile: profile, command: command)
        guard result.exitCode == 0 else {
            let detail = String(data: result.stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fallback = String(data: result.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw MihomoClientError.operationFailed(
                "mihomo.service SSH 执行失败：\(!detail.isEmpty ? detail : (!fallback.isEmpty ? fallback : "exit \(result.exitCode)"))"
            )
        }
        return String(data: result.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func sshLoopbackURL(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(),
              host != "localhost", host != "127.0.0.1", host != "::1" else { return nil }
        components.host = "127.0.0.1"
        return components.url
    }

    private var sshHTTPStatusMarker: String { "__MM_HTTP_STATUS__:" }

    private func sshHTTPCommand(method: String, target: URL, secret: String, hasBody: Bool, timeout: TimeInterval) -> String {
        let seconds = min(30, max(3, Int(timeout.rounded(.up))))
        var parts = [
            "curl", "--noproxy", shellQuote("*"), "-sS",
            "--connect-timeout", "4", "--max-time", String(seconds),
            "-X", shellQuote(method),
            "-H", shellQuote("Accept: application/json"),
            "-H", shellQuote("User-Agent: MihomoManager/1.3.2 (server-local SSH fallback)")
        ]
        if !secret.isEmpty {
            parts += ["-H", shellQuote("Authorization: Bearer \(secret)")]
        }
        if hasBody {
            parts += ["-H", shellQuote("Content-Type: application/json"), "--data-binary", "@-"]
        }
        parts += ["-w", shellQuote("\n\(sshHTTPStatusMarker)%{http_code}"), shellQuote(target.absoluteString)]
        return parts.joined(separator: " ")
    }

    private func parseSSHHTTPResponse(_ data: Data) throws -> (Data, Int) {
        let marker = Data(("\n" + sshHTTPStatusMarker).utf8)
        guard let range = data.range(of: marker, options: .backwards) else {
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw MihomoClientError.operationFailed(detail.isEmpty ? "远端 curl 未返回 HTTP 状态码" : detail)
        }
        let codeData = data[range.upperBound...]
        let codeText = String(data: codeData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let code = Int(codeText), code > 0 else {
            throw MihomoClientError.operationFailed("无法解析 SSH HTTP 状态码：\(codeText)")
        }
        return (Data(data[..<range.lowerBound]), code)
    }

    private func runHTTPOverSSHOnce(
        profile: ServerProfile,
        method: String,
        target: URL,
        body: Data?,
        secret: String,
        timeout: TimeInterval,
        backendLabel: String
    ) async throws -> Data {
        let command = sshHTTPCommand(method: method, target: target, secret: secret, hasBody: body != nil, timeout: timeout)
        let result = try await runSSHProcess(
            profile: profile,
            command: command,
            stdin: body ?? Data(),
            timeout: min(36, max(9, timeout + 6))
        )
        let combined = result.stdout + result.stderr
        do {
            let (data, status) = try parseSSHHTTPResponse(result.stdout)
            if (200..<300).contains(status) { return data }
            let error: Error = status == 401 && backendLabel == "Mihomo Controller"
                ? MihomoClientError.controllerUnauthorized
                : MihomoClientError.server(
                    status: status,
                    message: remoteErrorMessage(data: data, status: status, fallback: "\(backendLabel) request failed")
                )
            throw RemoteRequestFailure(data: data, status: status, error: error)
        } catch let failure as RemoteRequestFailure {
            throw failure
        } catch {
            let detail = String(data: combined, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if result.exitCode != 0 || !detail.isEmpty {
                throw RemoteRequestFailure(
                    data: Data(), status: 0,
                    error: MihomoClientError.operationFailed(detail.isEmpty ? "SSH 本机 HTTP 请求失败" : detail)
                )
            }
            throw error
        }
    }

    private func remoteRequestViaSSH(
        profile: ServerProfile,
        method: String,
        target: URL,
        body: Data?,
        secret: String,
        timeout: TimeInterval,
        backendLabel: String
    ) async throws -> Data {
        var candidates = [target]
        if let local = sshLoopbackURL(target), local != target { candidates.append(local) }
        var failures: [String] = []
        for candidate in candidates {
            do {
                return try await runHTTPOverSSHOnce(
                    profile: profile, method: method, target: candidate, body: body,
                    secret: secret, timeout: timeout, backendLabel: backendLabel
                )
            } catch let failure as RemoteRequestFailure {
                if failure.status > 0 { throw failure }
                failures.append(shortErrorMessage(failure.error))
            } catch {
                failures.append(shortErrorMessage(error))
            }
        }
        throw MihomoClientError.operationFailed(failures.joined(separator: "；"))
    }

    private func systemdStatus(profile: ServerProfile) async throws -> StatusPayload {
        let output = try await runSystemdSSH(
            profile: profile,
            command: "LC_ALL=C systemctl show mihomo.service --no-pager --property=LoadState --property=ActiveState --property=SubState --property=UnitFileState --property=MainPID --property=FragmentPath"
        )
        var values: [String: String] = [:]
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 { values[String(parts[0])] = String(parts[1]) }
        }
        guard let loadState = values["LoadState"], loadState != "not-found" else {
            throw MihomoClientError.operationFailed("服务器未找到 mihomo.service（systemd: not-found）")
        }
        let activeState = values["ActiveState"] ?? "unknown"
        let subState = values["SubState"] ?? "unknown"
        let unitFileState = values["UnitFileState"]
        let pid = Int(values["MainPID"] ?? "")
        return StatusPayload(
            ok: true,
            service: ServiceStatus(
                manager: "systemd · mihomo.service",
                active: activeState == "active",
                activeState: activeState,
                subState: subState,
                enabled: unitFileState?.hasPrefix("enabled"),
                unitFileState: unitFileState,
                pid: pid,
                unitFilePath: values["FragmentPath"]
            ),
            uptimeSeconds: nil,
            memoryBytes: nil,
            speed: nil,
            totals: nil,
            connections: nil,
            versions: nil,
            version: nil,
            management: nil,
            corePublicUrl: nil,
            controller: normalizedControllerURL(profile.coreControllerURL),
            metacubexd: nil
        )
    }

    private func systemdCanReload(profile: ServerProfile) async -> Bool {
        guard let output = try? await runSystemdSSH(
            profile: profile,
            command: "LC_ALL=C systemctl show mihomo.service --no-pager --property=CanReload --value"
        ) else { return false }
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "yes" || value == "true" || value == "1"
    }

    private func systemdLifecycleAction(_ action: CoreAction, profile: ServerProfile) async throws -> String {
        let verb: String
        switch action {
        case .start: verb = "start"
        case .stop: verb = "stop"
        case .restart: verb = "restart"
        case .reload:
            guard await systemdCanReload(profile: profile) else {
                throw MihomoClientError.operationFailed("mihomo.service 未声明 ExecReload/CanReload；跳过无效的 systemctl reload")
            }
            verb = "reload"
        case .applySubscriptions:
            throw MihomoClientError.operationFailed("mihomo.service 不负责生成订阅配置")
        }
        // v4.0.1 deliberately keeps Mihomo disabled at boot when the panel starts
        // or restarts it. Direct systemd control must preserve that deployment
        // policy instead of silently diverging from /api/action.
        let keepBootDisabled = (action == .start || action == .restart)
            ? "if [ \"$(id -u)\" -eq 0 ]; then systemctl disable mihomo.service >/dev/null 2>&1 || true; else sudo -n systemctl disable mihomo.service >/dev/null 2>&1 || true; fi; "
            : ""
        let command = keepBootDisabled + "if [ \"$(id -u)\" -eq 0 ]; then systemctl \(verb) mihomo.service; else sudo -n systemctl \(verb) mihomo.service; fi"
        _ = try await runSystemdSSH(profile: profile, command: command)
        return "已通过 mihomo.service（systemd/SSH）执行 \(action.displayName)"
    }

    private func systemdLogs(lines: Int, profile: ServerProfile) async throws -> String {
        let safe = min(300, max(10, lines))
        let command = "journalctl -u mihomo.service -n \(safe) --no-pager -o short-iso 2>/dev/null || sudo -n journalctl -u mihomo.service -n \(safe) --no-pager -o short-iso"
        return try await runSystemdSSH(profile: profile, command: command)
    }

    func status(
        profile: ServerProfile,
        managementSecret: String,
        controllerSecret: String
    ) async throws -> StatusPayload {
        // v1.3.2 priority:
        // 1) Mihomo Controller API (authoritative live Core telemetry)
        // 2) Core management panel API (works even when Core itself is stopped)
        // 3) explicit-only SSH/systemd advanced fallback.
        var failures: [String] = []
        if profile.hasControllerEndpoint {
            do {
                return try await controllerStatus(profile: profile, secret: controllerSecret)
            } catch {
                failures.append("Controller：\(shortErrorMessage(error))")
            }
        }
        if profile.hasManagementEndpoint, !managementSecret.isEmpty {
            do {
                return try await managementStatus(profile: profile, secret: managementSecret)
            } catch {
                failures.append("Core 服务面板：\(shortErrorMessage(error))")
            }
        }
        if profile.hasSystemdServiceEndpoint {
            do {
                return try await systemdStatus(profile: profile)
            } catch {
                failures.append("显式 SSH/mihomo.service：\(shortErrorMessage(error))")
            }
        }
        if !failures.isEmpty {
            throw MihomoClientError.operationFailed(failures.joined(separator: "；"))
        }
        throw MihomoClientError.missingController
    }

    private func managementStatus(profile: ServerProfile, secret: String) async throws -> StatusPayload {
        try await get("/api/status", profile: profile, secret: secret)
    }

    /// Slow-changing deployment metadata (Core panel / MetaCubeXD versions,
    /// unit/path details) lives only on the v4.0.1 management surface. AppModel
    /// calls this on a 30 s side cadence and merges it into Controller/systemd
    /// telemetry, so `/api/status` is not polled every 1.2 s.
    func managementMetadata(profile: ServerProfile, secret: String) async throws -> StatusPayload {
        guard profile.hasManagementEndpoint, !secret.isEmpty else {
            throw MihomoClientError.missingManagement
        }
        return try await managementStatus(profile: profile, secret: secret)
    }

    private func controllerStatus(profile: ServerProfile, secret: String) async throws -> StatusPayload {
        let versionData = try await controllerData(
            path: "/version",
            method: "GET",
            body: nil,
            profile: profile,
            secret: secret
        )
        let version = (try? decoder.decode(ControllerVersionResponse.self, from: versionData))?.version

        var totals: TotalsInfo?
        var connections: Int?
        var memoryBytes: Int64?
        if let connectionData = try? await controllerData(
            path: "/connections",
            method: "GET",
            body: nil,
            profile: profile,
            secret: secret
        ), let snapshot = try? decoder.decode(ControllerConnectionsStatusResponse.self, from: connectionData) {
            totals = TotalsInfo(up: snapshot.uploadTotal, down: snapshot.downloadTotal)
            connections = snapshot.connections?.count
            memoryBytes = snapshot.memory
        }

        return StatusPayload(
            ok: true,
            service: ServiceStatus(
                manager: "Mihomo Controller",
                active: true,
                activeState: "active",
                subState: "running",
                enabled: nil,
                unitFileState: nil,
                pid: nil,
                unitFilePath: nil
            ),
            uptimeSeconds: nil,
            memoryBytes: memoryBytes,
            speed: nil,
            totals: totals,
            connections: connections,
            versions: VersionsInfo(core: version, managementPanel: nil, metacubexd: nil),
            version: version,
            management: nil,
            corePublicUrl: nil,
            controller: normalizedControllerURL(profile.coreControllerURL),
            metacubexd: nil
        )
    }

    func subscriptions(profile: ServerProfile, secret: String) async throws -> [String: String] {
        let response: SubscriptionsResponse = try await get("/api/subscriptions", profile: profile, secret: secret)
        return response.subscriptions
    }

    func saveSubscriptions(_ values: [String: String], profile: ServerProfile, secret: String) async throws -> String {
        do {
            return try await saveSubscriptionsTransaction(values, profile: profile, secret: secret)
        } catch {
            guard shouldRetrySubscriptionApplyWithRestart(error) else { throw error }

            // Mihomo Core 管理面板 v4.0.1 将“保存订阅 + renderer + 热重载”放在
            // 同一个事务里。部分远端 Core 在 /configs 热重载时会超时，于是服务端
            // 为保证安全会回滚 subscriptions.conf/config.yaml。客户端兼容层在这种
            // 明确的“热重载超时 + 已回滚”场景下改用一次安全重启：先停止 Core，
            // 再调用同一个 v4.0.1 事务（此时不会触发热重载），最后重新启动 Core。
            do {
                _ = try await action(.stop, profile: profile, secret: secret)
                try? await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                throw MihomoClientError.operationFailed(
                    "订阅保存时远端热重载超时；自动安全重启也无法停止 Core：\(shortErrorMessage(error))"
                )
            }

            do {
                _ = try await saveSubscriptionsTransaction(values, profile: profile, secret: secret)
            } catch {
                // 配置事务未提交时尽量恢复原来的运行状态。
                _ = try? await action(.start, profile: profile, secret: secret)
                throw MihomoClientError.operationFailed(
                    "订阅保存时远端热重载超时；停止 Core 后再次保存仍失败：\(shortErrorMessage(error))"
                )
            }

            do {
                _ = try await action(.start, profile: profile, secret: secret)
            } catch {
                throw MihomoClientError.operationFailed(
                    "订阅配置已经保存，但 Core 重新启动失败：\(shortErrorMessage(error))。请到 Core 控制页手动启动。"
                )
            }

            return "订阅已保存并应用；远端热重载超时，已自动通过安全重启 Core 应用新配置。"
        }
    }

    private func saveSubscriptionsTransaction(
        _ values: [String: String],
        profile: ServerProfile,
        secret: String
    ) async throws -> String {
        struct Payload: Encodable { let subscriptions: [String: String] }
        let response: APIMessage = try await post(
            "/api/subscriptions",
            payload: Payload(subscriptions: values),
            profile: profile,
            secret: secret
        )
        return response.message ?? "订阅已保存并应用"
    }

    private func shouldRetrySubscriptionApplyWithRestart(_ error: Error) -> Bool {
        guard let clientError = error as? MihomoClientError,
              case .server(_, let message) = clientError else { return false }
        let lower = message.lowercased()
        let reloadFailed = message.contains("热重载失败") || message.contains("Mihomo 热重载失败")
        let timedOut = lower.contains("timed out") || lower.contains("timeout") || message.contains("超时")
        let rolledBack = message.contains("已恢复") || message.contains("回滚")
        return reloadFailed && timedOut && rolledBack
    }

    private func shortErrorMessage(_ error: Error) -> String {
        if let clientError = error as? MihomoClientError,
           case .server(_, let message) = clientError { return message }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func managementAction(_ action: CoreAction, profile: ServerProfile, secret: String) async throws -> String {
        struct Payload: Encodable { let action: String }
        let response: APIMessage = try await post("/api/action", payload: Payload(action: action.rawValue), profile: profile, secret: secret)
        return response.message ?? "操作完成"
    }

    func action(_ action: CoreAction, profile: ServerProfile, secret: String) async throws -> String {
        switch action {
        case .start, .stop, .restart, .reload:
            var panelError: Error?
            if profile.hasManagementEndpoint, !secret.isEmpty {
                do { return try await managementAction(action, profile: profile, secret: secret) }
                catch { panelError = error }
            }
            if profile.hasSystemdServiceEndpoint {
                do { return try await systemdLifecycleAction(action, profile: profile) }
                catch {
                    if let panelError {
                        throw MihomoClientError.operationFailed(
                            "Core 服务面板 API 失败：\(shortErrorMessage(panelError))；显式 SSH/mihomo.service 回退也失败：\(shortErrorMessage(error))"
                        )
                    }
                    throw error
                }
            }
            if let panelError { throw panelError }
            throw MihomoClientError.missingManagement
        case .applySubscriptions:
            return try await managementAction(action, profile: profile, secret: secret)
        }
    }

    func restartCore(
        profile: ServerProfile,
        managementSecret: String,
        controllerSecret: String
    ) async throws -> String {
        // Preference order is Core API -> Core management panel API -> explicit SSH.
        var lastError: Error?
        if profile.hasControllerEndpoint {
            struct Payload: Encodable { let path: String; let payload: String }
            let body = try encoder.encode(Payload(path: profile.configPath, payload: ""))
            do {
                _ = try await controllerData(
                    path: "/restart",
                    method: "POST",
                    body: body,
                    profile: profile,
                    secret: controllerSecret
                )
                return "已通过 Mihomo Core API 重启 Core"
            } catch {
                lastError = error
            }
        }
        if profile.hasManagementEndpoint, !managementSecret.isEmpty {
            do { return try await managementAction(.restart, profile: profile, secret: managementSecret) }
            catch { lastError = error }
        }
        if profile.hasSystemdServiceEndpoint {
            do { return try await systemdLifecycleAction(.restart, profile: profile) }
            catch { lastError = error }
        }
        if let lastError { throw lastError }
        throw MihomoClientError.missingManagement
    }

    func reloadConfiguredPath(
        profile: ServerProfile,
        managementSecret: String,
        controllerSecret: String
    ) async throws -> String {
        var lastError: Error?
        let direct = profile.coreControllerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !direct.isEmpty {
            do {
                let url = try makeURL(
                    base: try normalizedControllerBase(direct, allowInsecureHTTP: profile.allowInsecureHTTP),
                    path: "/configs",
                    queryItems: [URLQueryItem(name: "force", value: "true")],
                    allowInsecureHTTP: profile.allowInsecureHTTP
                )
                struct Payload: Encodable { let path: String; let payload: String }
                let body = try encoder.encode(Payload(path: profile.configPath, payload: ""))
                _ = try await controllerData(
                    url: url, method: "PUT", body: body, profile: profile, secret: controllerSecret
                )
                return "已通过 Mihomo Core API 重载 \(profile.configPath)"
            } catch {
                lastError = error
            }
        }
        if profile.hasManagementEndpoint, !managementSecret.isEmpty {
            do { return try await managementAction(.reload, profile: profile, secret: managementSecret) }
            catch { lastError = error }
        }
        if profile.hasSystemdServiceEndpoint {
            do { return try await systemdLifecycleAction(.reload, profile: profile) }
            catch { lastError = error }
        }
        if let lastError { throw lastError }
        throw MihomoClientError.missingController
    }

    func proxyMode(profile: ServerProfile, secret: String) async throws -> MihomoRunMode? {
        let data = try await controllerData(path: "/configs", method: "GET", body: nil, profile: profile, secret: secret)
        let response: ControllerConfigResponse
        do {
            response = try decoder.decode(ControllerConfigResponse.self, from: data)
        } catch {
            throw MihomoClientError.invalidResponse
        }
        guard let raw = response.mode?.lowercased() else { return nil }
        return MihomoRunMode(rawValue: raw)
    }

    func setProxyMode(_ mode: MihomoRunMode, profile: ServerProfile, secret: String) async throws {
        struct Payload: Encodable { let mode: String }
        let body = try encoder.encode(Payload(mode: mode.rawValue))
        _ = try await controllerData(path: "/configs", method: "PATCH", body: body, profile: profile, secret: secret)
    }

    func proxies(profile: ServerProfile, secret: String) async throws -> [MihomoProxy] {
        async let proxyData = controllerData(
            path: "/proxies",
            method: "GET",
            body: nil,
            profile: profile,
            secret: secret
        )
        async let providerDataTask = controllerData(
            path: "/providers/proxies",
            method: "GET",
            body: nil,
            profile: profile,
            secret: secret
        )
        // Some Controller builds expose a complete group `now` value through
        // /group even when the bulk /proxies payload omits it. Fetch that one
        // small snapshot in parallel and merge it below. This keeps the native
        // GitHub/Xcode MenuBarExtra able to show the selected route reliably.
        async let groupDataTask = controllerData(
            path: "/group",
            method: "GET",
            body: nil,
            profile: profile,
            secret: secret
        )

        let data = try await proxyData
        let providerData = try? await providerDataTask
        let groupData = try? await groupDataTask
        let response: ControllerProxiesResponse
        do {
            response = try decoder.decode(ControllerProxiesResponse.self, from: data)
        } catch {
            throw MihomoClientError.invalidResponse
        }

        var merged = response.proxies

        // Provider leaf nodes are not guaranteed to be present in /proxies.
        // MetaCubeXD explicitly merges /providers/proxies so every group member
        // has its own alive/history/extra latency information.
        if let providerData,
           let providers = try? decoder.decode(ControllerProvidersResponse.self, from: providerData) {
            for (providerKey, provider) in providers.providers {
                for wire in provider.proxies ?? [] {
                    guard let name = wire.name, !name.isEmpty else { continue }
                    if merged[name] == nil {
                        merged[name] = wire
                    }
                }

                // Some provider-backed groups inherit their health-check URL
                // from the provider. Preserve that URL for group latency display
                // when the group object itself omitted testUrl.
                if let current = merged[providerKey],
                   current.testUrl == nil,
                   let inheritedURL = provider.testUrl,
                   !inheritedURL.isEmpty {
                    merged[providerKey] = ControllerProxyWire(
                        name: current.name,
                        type: current.type,
                        now: current.now,
                        all: current.all,
                        history: current.history,
                        extra: current.extra,
                        alive: current.alive,
                        hidden: current.hidden,
                        udp: current.udp,
                        xudp: current.xudp,
                        tfo: current.tfo,
                        testUrl: inheritedURL,
                        expectedStatus: current.expectedStatus
                    )
                }
            }
        }

        if let groupData,
           let groups = try? decoder.decode(ControllerGroupsResponse.self, from: groupData) {
            for group in groups.proxies {
                guard let name = group.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { continue }

                guard let current = merged[name] else {
                    merged[name] = group
                    continue
                }

                // Prefer /group for dynamic group metadata (`now` in particular),
                // but keep richer /proxies/provider history and capability data.
                // This is intentionally a field-by-field merge rather than a
                // replacement so latency/provider information is never lost.
                merged[name] = ControllerProxyWire(
                    name: current.name ?? group.name,
                    type: current.type ?? group.type,
                    now: group.now?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? group.now
                        : current.now,
                    all: (current.all?.isEmpty == false ? current.all : group.all),
                    history: current.history ?? group.history,
                    extra: current.extra ?? group.extra,
                    alive: current.alive ?? group.alive,
                    hidden: current.hidden ?? group.hidden,
                    udp: current.udp ?? group.udp,
                    xudp: current.xudp ?? group.xudp,
                    tfo: current.tfo ?? group.tfo,
                    testUrl: current.testUrl ?? group.testUrl,
                    expectedStatus: current.expectedStatus ?? group.expectedStatus
                )
            }
        }

        return merged.map { key, value in
            MihomoProxy(
                name: value.name ?? key,
                type: value.type ?? "Unknown",
                now: value.now,
                all: value.all ?? [],
                history: value.history ?? [],
                extra: value.extra ?? [:],
                alive: value.alive,
                hidden: value.hidden,
                udp: value.udp,
                xudp: value.xudp,
                tfo: value.tfo,
                testURL: value.testUrl,
                expectedStatus: value.expectedStatus
            )
        }
        .sorted { lhs, rhs in
            if lhs.name == "GLOBAL" { return true }
            if rhs.name == "GLOBAL" { return false }
            if lhs.isGroup != rhs.isGroup { return lhs.isGroup }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func proxyGroupOrder(profile: ServerProfile, secret: String) async -> [String] {
        do {
            let data = try await controllerData(path: "/group", method: "GET", body: nil, profile: profile, secret: secret)
            let response = try decoder.decode(ControllerGroupsResponse.self, from: data)
            return response.proxies.compactMap(\.name)
        } catch {
            // /group is a v1.2.4 ordering enhancement. Keep /proxies usable on
            // older Controllers that do not expose this endpoint.
            return []
        }
    }

    func testProxyGroup(
        _ group: MihomoProxy,
        profile: ServerProfile,
        secret: String,
        timeout: Int = 5_000
    ) async throws -> [String: Int] {
        let base = try controllerBase(profile: profile, secret: secret)
        let fallbackURL = "https://www.gstatic.com/generate_204"
        let testURL = group.testURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        var queryItems = [
            URLQueryItem(name: "url", value: (testURL?.isEmpty == false ? testURL : nil) ?? fallbackURL),
            URLQueryItem(name: "timeout", value: String(max(1_000, min(timeout, 30_000))))
        ]
        if let expected = group.expectedStatus?.trimmingCharacters(in: .whitespacesAndNewlines),
           !expected.isEmpty {
            queryItems.append(URLQueryItem(name: "expected", value: expected))
        }

        let url = try makeControllerNamedURL(
            base: base,
            collection: "group",
            name: group.name,
            suffix: "delay",
            queryItems: queryItems,
            allowInsecureHTTP: profile.allowInsecureHTTP
        )
        let data = try await controllerData(url: url, method: "GET", body: nil, profile: profile, secret: secret)

        // Mihomo currently returns {"node": uint16}, but use JSONSerialization
        // here so an NSNumber/string representation from a compatible build
        // cannot make a successful group test look like it produced no latency.
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MihomoClientError.invalidResponse
        }
        var result: [String: Int] = [:]
        for (name, value) in raw {
            if let number = value as? NSNumber {
                result[name] = number.intValue
            } else if let string = value as? String, let delay = Int(string) {
                result[name] = delay
            }
        }
        guard !raw.isEmpty ? !result.isEmpty : true else {
            throw MihomoClientError.invalidResponse
        }
        return result
    }

    func selectProxy(_ proxyName: String, in groupName: String, profile: ServerProfile, secret: String) async throws {
        struct Payload: Encodable { let name: String }
        let body = try encoder.encode(Payload(name: proxyName))
        let base = try controllerBase(profile: profile, secret: secret)
        let url = try makeProxyGroupURL(
            base: base,
            group: groupName,
            allowInsecureHTTP: profile.allowInsecureHTTP
        )
        _ = try await controllerData(url: url, method: "PUT", body: body, profile: profile, secret: secret)
    }

    func portManagement(profile: ServerProfile, secret: String) async throws -> PortManagementPayload {
        try await get("/api/ports", profile: profile, secret: secret)
    }

    func savePortSettings(
        _ settings: [PortSettingUpdate],
        profile: ServerProfile,
        secret: String
    ) async throws -> String {
        struct Payload: Encodable { let settings: [PortSettingUpdate] }
        let response: APIMessage = try await post(
            "/api/ports/settings",
            payload: Payload(settings: settings),
            profile: profile,
            secret: secret
        )
        return response.message ?? "端口设置已保存"
    }

    func refreshRouteDelay(
        _ target: String,
        profile: ServerProfile,
        secret: String
    ) async throws -> Int {
        struct Payload: Encodable { let target: String }
        struct Response: Decodable {
            let ok: Bool
            let message: String?
            let delay: Int?
        }
        let response: Response = try await post(
            "/api/ports/delay",
            payload: Payload(target: target),
            profile: profile,
            secret: secret
        )
        guard let delay = response.delay, delay > 0 else {
            throw MihomoClientError.operationFailed(response.message ?? "线路延时刷新失败")
        }
        return delay
    }

    func logs(lines: Int, profile: ServerProfile, secret: String) async throws -> String {
        var panelError: Error?
        if profile.hasManagementEndpoint, !secret.isEmpty {
            do {
                let safe = min(300, max(10, lines))
                let response: LogsResponse = try await get(
                    "/api/logs",
                    queryItems: [URLQueryItem(name: "lines", value: String(safe))],
                    profile: profile,
                    secret: secret
                )
                return response.logs
            } catch {
                panelError = error
            }
        }
        if profile.hasSystemdServiceEndpoint {
            do { return try await systemdLogs(lines: lines, profile: profile) }
            catch {
                if let panelError {
                    throw MihomoClientError.operationFailed(
                        "Core 服务面板日志 API 失败：\(shortErrorMessage(panelError))；显式 SSH journalctl 回退也失败：\(shortErrorMessage(error))"
                    )
                }
                throw error
            }
        }
        if let panelError { throw panelError }
        throw MihomoClientError.missingManagement
    }

    func checkUpdate(profile: ServerProfile, secret: String) async throws -> ProjectUpdateInfo {
        let response: UpdateCheckResponse = try await get("/api/project-update/check", profile: profile, secret: secret)
        return response.updates
    }

    func applyUpdate(preserveSettings: Bool, profile: ServerProfile, secret: String) async throws -> String {
        struct Payload: Encodable { let preserveSettings: Bool }
        let response: APIMessage = try await post(
            "/api/project-update/apply",
            payload: Payload(preserveSettings: preserveSettings),
            profile: profile,
            secret: secret
        )
        return response.message ?? "项目升级已启动"
    }

    func updateLog(profile: ServerProfile, secret: String) async throws -> UpdateLogResponse {
        try await get("/api/project-update/log", profile: profile, secret: secret)
    }

    private func get<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        profile: ServerProfile,
        secret: String
    ) async throws -> Response {
        try await send(path, queryItems: queryItems, method: "GET", body: nil, profile: profile, secret: secret)
    }

    private func post<Payload: Encodable, Response: Decodable>(
        _ path: String,
        payload: Payload,
        profile: ServerProfile,
        secret: String
    ) async throws -> Response {
        let body = try encoder.encode(payload)
        return try await send(path, method: "POST", body: body, profile: profile, secret: secret)
    }

    private func send<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        method: String,
        body: Data?,
        profile: ServerProfile,
        secret: String
    ) async throws -> Response {
        let managementBase = normalizedManagementURL(profile.managementURL)
        guard !managementBase.isEmpty else { throw MihomoClientError.missingManagement }
        guard !secret.isEmpty else { throw MihomoClientError.missingSecret }
        let url = try makeURL(
            base: managementBase,
            path: path,
            queryItems: queryItems,
            allowInsecureHTTP: profile.allowInsecureHTTP
        )
        let timeout: TimeInterval = method == "GET" && path == "/api/status" ? 6 : 20
        let data = try await requestDataWithSSHFallback(
            profile: profile,
            backendLabel: "Core 服务面板",
            url: url,
            method: method,
            body: body,
            secret: secret,
            timeout: timeout
        )
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw MihomoClientError.invalidResponse
        }
    }

    private func controllerBase(profile: ServerProfile, secret: String) throws -> String {
        let direct = profile.coreControllerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !direct.isEmpty else { throw MihomoClientError.missingController }
        return try normalizedControllerBase(direct, allowInsecureHTTP: profile.allowInsecureHTTP)
    }

    private func normalizedControllerBase(_ rawBase: String, allowInsecureHTTP: Bool) throws -> String {
        var base = normalizedControllerURL(rawBase)
        if !base.contains("://") { base = "http://" + base }
        guard let components = URLComponents(string: base),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host else {
            throw MihomoClientError.invalidURL(rawBase)
        }
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")).lowercased()
        if normalizedHost == "0.0.0.0" || normalizedHost == "::" {
            throw MihomoClientError.operationFailed("0.0.0.0 / :: 是服务端监听地址，不是客户端目标；请填写服务器实际 LAN IP、主机名或公网域名")
        }
        if scheme == "http" && !allowInsecureHTTP {
            throw MihomoClientError.insecureHTTPDisabled
        }
        return base
    }

    private func controllerData(
        path: String,
        method: String,
        body: Data?,
        profile: ServerProfile,
        secret: String
    ) async throws -> Data {
        let base = try controllerBase(profile: profile, secret: secret)
        let url = try makeURL(
            base: base,
            path: path,
            allowInsecureHTTP: profile.allowInsecureHTTP
        )
        return try await controllerData(url: url, method: method, body: body, profile: profile, secret: secret)
    }

    private func isTransientControllerStatus(_ status: Int) -> Bool {
        switch status {
        case 502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 530:
            true
        default:
            false
        }
    }

    private func remoteErrorMessage(data: Data, status: Int, fallback: String) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let errorCode = (object["error_code"] as? NSNumber)?.intValue
                ?? Int((object["error_code"] as? String) ?? "")
            let title = (object["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = (object["detail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = (object["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if errorCode == 1033
                || title.lowercased().contains("error 1033")
                || detail.lowercased().contains("cloudflare tunnel") {
                return "Cloudflare Tunnel 暂时断开（Error 1033）。Controller 主机当前不可达，请稍后重试。"
            }
            if !message.isEmpty { return message }
            if !title.isEmpty && !detail.isEmpty { return "\(title)：\(detail)" }
            if !detail.isEmpty { return detail }
            if !title.isEmpty { return title }
        }

        if let response = try? decoder.decode(ControllerErrorMessage.self, from: data),
           let decoded = response.message,
           !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return decoded
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if status == 530 {
            let lower = raw.lowercased()
            if lower.contains("1033") || lower.contains("cloudflare") {
                return "Cloudflare Tunnel 暂时断开（Error 1033）。Controller 主机当前不可达，请稍后重试。"
            }
        }
        return raw.isEmpty ? fallback : raw
    }

    private func directRequestData(
        url: URL,
        method: String,
        body: Data?,
        secret: String,
        backendLabel: String,
        timeout: TimeInterval
    ) async throws -> Data {
        let isReadOnly = ["GET", "HEAD"].contains(method.uppercased())
        let maxAttempts = isReadOnly ? 2 : 1
        var lastFailure = RemoteRequestFailure(data: Data(), status: 0, error: MihomoClientError.invalidResponse)

        for attempt in 1...maxAttempts {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = timeout
            if !secret.isEmpty {
                request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("MihomoManager/1.3.2 (macOS; SwiftUI)", forHTTPHeaderField: "User-Agent")
            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw RemoteRequestFailure(data: data, status: 0, error: MihomoClientError.invalidResponse)
                }
                if (200..<300).contains(http.statusCode) { return data }

                let error: Error = http.statusCode == 401 && backendLabel == "Mihomo Controller"
                    ? MihomoClientError.controllerUnauthorized
                    : MihomoClientError.server(
                        status: http.statusCode,
                        message: remoteErrorMessage(data: data, status: http.statusCode, fallback: "\(backendLabel) request failed")
                    )
                let failure = RemoteRequestFailure(data: data, status: http.statusCode, error: error)
                lastFailure = failure
                if attempt < maxAttempts && isTransientControllerStatus(http.statusCode) {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 180_000_000)
                    continue
                }
                throw failure
            } catch let failure as RemoteRequestFailure {
                lastFailure = failure
                if attempt < maxAttempts && failure.status == 0 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 180_000_000)
                    continue
                }
                throw failure
            } catch {
                let failure = RemoteRequestFailure(data: Data(), status: 0, error: error)
                lastFailure = failure
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 180_000_000)
                    continue
                }
                throw failure
            }
        }
        throw lastFailure
    }

    private func requestDataWithSSHFallback(
        profile: ServerProfile,
        backendLabel: String,
        url: URL,
        method: String,
        body: Data?,
        secret: String,
        timeout: TimeInterval
    ) async throws -> Data {
        do {
            return try await directRequestData(
                url: url, method: method, body: body, secret: secret,
                backendLabel: backendLabel, timeout: timeout
            )
        } catch let directFailure as RemoteRequestFailure {
            let mayFallback = directFailure.status == 0 || isTransientControllerStatus(directFailure.status)
            guard mayFallback, systemdSSHTarget(profile: profile) != nil else {
                throw directFailure.error
            }
            do {
                return try await remoteRequestViaSSH(
                    profile: profile, method: method, target: url, body: body,
                    secret: secret, timeout: timeout, backendLabel: backendLabel
                )
            } catch let sshFailure as RemoteRequestFailure {
                if sshFailure.status > 0 { throw sshFailure.error }
                throw MihomoClientError.operationFailed(
                    "\(backendLabel)直连失败：\(shortErrorMessage(directFailure.error))；SSH 到服务器后的原地址/本机回环回退也失败：\(shortErrorMessage(sshFailure.error))"
                )
            } catch {
                throw MihomoClientError.operationFailed(
                    "\(backendLabel)直连失败：\(shortErrorMessage(directFailure.error))；SSH 到服务器后的原地址/本机回环回退也失败：\(shortErrorMessage(error))"
                )
            }
        }
    }

    private func controllerData(
        url: URL,
        method: String,
        body: Data?,
        profile: ServerProfile,
        secret: String
    ) async throws -> Data {
        try await requestDataWithSSHFallback(
            profile: profile,
            backendLabel: "Mihomo Controller",
            url: url,
            method: method,
            body: body,
            secret: secret,
            timeout: ["GET", "HEAD"].contains(method.uppercased()) ? 10 : 20
        )
    }

    private func makeProxyGroupURL(
        base rawBase: String,
        group: String,
        allowInsecureHTTP: Bool
    ) throws -> URL {
        try makeControllerNamedURL(
            base: rawBase,
            collection: "proxies",
            name: group,
            allowInsecureHTTP: allowInsecureHTTP
        )
    }

    private func makeControllerNamedURL(
        base rawBase: String,
        collection: String,
        name: String,
        suffix: String? = nil,
        queryItems: [URLQueryItem] = [],
        allowInsecureHTTP: Bool
    ) throws -> URL {
        let collectionURL = try makeURL(
            base: try normalizedControllerBase(rawBase, allowInsecureHTTP: allowInsecureHTTP),
            path: "/\(collection)",
            allowInsecureHTTP: allowInsecureHTTP
        )
        guard var components = URLComponents(url: collectionURL, resolvingAgainstBaseURL: false) else {
            throw MihomoClientError.invalidURL(rawBase)
        }

        let segmentAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: segmentAllowed) else {
            throw MihomoClientError.invalidURL(rawBase)
        }

        var pathParts = [components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")), encodedName]
            .filter { !$0.isEmpty }
        if let suffix, !suffix.isEmpty {
            pathParts.append(suffix)
        }
        components.percentEncodedPath = "/" + pathParts.joined(separator: "/")
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw MihomoClientError.invalidURL(rawBase) }
        return url
    }

    private func makeURL(
        base rawBase: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        allowInsecureHTTP: Bool
    ) throws -> URL {
        var base = rawBase.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.contains("://") { base = "https://" + base }
        guard var components = URLComponents(string: base),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host else {
            throw MihomoClientError.invalidURL(rawBase)
        }
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")).lowercased()
        if normalizedHost == "0.0.0.0" || normalizedHost == "::" {
            throw MihomoClientError.operationFailed("0.0.0.0 / :: 是服务端监听地址，不是客户端目标；请填写服务器实际 LAN IP、主机名或公网域名")
        }
        if scheme == "http" && !allowInsecureHTTP {
            throw MihomoClientError.insecureHTTPDisabled
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let requestPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let joined = [basePath, requestPath].filter { !$0.isEmpty }.joined(separator: "/")
        components.path = "/" + joined
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw MihomoClientError.invalidURL(rawBase) }
        return url
    }
}
