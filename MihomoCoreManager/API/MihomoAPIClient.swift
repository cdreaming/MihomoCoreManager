import Foundation

<<<<<<< HEAD
private struct ControllerConfigResponse: Decodable {
    let mode: String?
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

=======
>>>>>>> parent of 7d39e5c (v1.2.3)
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
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    func status(profile: ServerProfile, secret: String) async throws -> StatusPayload {
        try await get("/api/status", profile: profile, secret: secret)
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

            // Mihomo Core 管理面板 v4.0.0 将“保存订阅 + renderer + 热重载”放在
            // 同一个事务里。部分远端 Core 在 /configs 热重载时会超时，于是服务端
            // 为保证安全会回滚 subscriptions.conf/config.yaml。客户端兼容层在这种
            // 明确的“热重载超时 + 已回滚”场景下改用一次安全重启：先停止 Core，
            // 再调用同一个 v4.0.0 事务（此时不会触发热重载），最后重新启动 Core。
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

    func action(_ action: CoreAction, profile: ServerProfile, secret: String) async throws -> String {
        struct Payload: Encodable { let action: String }
        let response: APIMessage = try await post("/api/action", payload: Payload(action: action.rawValue), profile: profile, secret: secret)
        return response.message ?? "操作完成"
    }

    func reloadConfiguredPath(profile: ServerProfile, secret: String) async throws -> String {
        let direct = profile.coreControllerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !direct.isEmpty else {
            return try await action(.reload, profile: profile, secret: secret)
        }
        guard !secret.isEmpty else { throw MihomoClientError.missingSecret }
        let url = try makeURL(
            base: direct,
            path: "/configs",
            queryItems: [URLQueryItem(name: "force", value: "true")],
            allowInsecureHTTP: profile.allowInsecureHTTP
        )
        struct Payload: Encodable { let path: String; let payload: String }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(Payload(path: profile.configPath, payload: ""))
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MihomoClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw MihomoClientError.server(status: http.statusCode, message: "Controller 拒绝重载配置")
        }
        return "已通过 Direct Controller 重载 \(profile.configPath)"
    }

<<<<<<< HEAD
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

        let data = try await proxyData
        let providerData = try? await providerDataTask
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
        let data = try await controllerData(url: url, method: "GET", body: nil, secret: secret)

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
        _ = try await controllerData(url: url, method: "PUT", body: body, secret: secret)
    }

=======
>>>>>>> parent of 7d39e5c (v1.2.3)
    func logs(lines: Int, profile: ServerProfile, secret: String) async throws -> String {
        let safe = min(300, max(10, lines))
        let response: LogsResponse = try await get(
            "/api/logs",
            queryItems: [URLQueryItem(name: "lines", value: String(safe))],
            profile: profile,
            secret: secret
        )
        return response.logs
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
        guard !secret.isEmpty else { throw MihomoClientError.missingSecret }
        let url = try makeURL(
            base: profile.managementURL,
            path: path,
            queryItems: queryItems,
            allowInsecureHTTP: profile.allowInsecureHTTP
        )
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MihomoClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIMessage.self, from: data).message)
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown response"
            throw MihomoClientError.server(status: http.statusCode, message: message)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw MihomoClientError.invalidResponse
        }
    }

<<<<<<< HEAD
    private func controllerBase(profile: ServerProfile, secret: String) throws -> String {
        let direct = profile.coreControllerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !direct.isEmpty else { throw MihomoClientError.missingController }
        return direct
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
        return try await controllerData(url: url, method: method, body: body, secret: secret)
    }

    private func isTransientControllerStatus(_ status: Int) -> Bool {
        switch status {
        case 502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 530:
            true
        default:
            false
        }
    }

    private func controllerErrorMessage(data: Data, status: Int) -> String {
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
        return raw.isEmpty ? "Controller request failed" : raw
    }

    private func controllerData(
        url: URL,
        method: String,
        body: Data?,
        secret: String
    ) async throws -> Data {
        let maxAttempts = ["GET", "HEAD"].contains(method.uppercased()) ? 3 : 1
        var lastError: Error = MihomoClientError.invalidResponse

        for attempt in 1...maxAttempts {
            var request = URLRequest(url: url)
            request.httpMethod = method
            if !secret.isEmpty {
                request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw MihomoClientError.invalidResponse
                }

                if (200..<300).contains(http.statusCode) {
                    return data
                }
                if http.statusCode == 401 {
                    throw MihomoClientError.controllerUnauthorized
                }

                let error = MihomoClientError.server(
                    status: http.statusCode,
                    message: controllerErrorMessage(data: data, status: http.statusCode)
                )
                lastError = error

                if attempt < maxAttempts && isTransientControllerStatus(http.statusCode) {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 250_000_000)
                    continue
                }
                throw error
            } catch let error as MihomoClientError {
                throw error
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 250_000_000)
                    continue
                }
                throw error
            }
        }

        throw lastError
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
            base: rawBase,
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

=======
>>>>>>> parent of 7d39e5c (v1.2.3)
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
              components.host != nil else {
            throw MihomoClientError.invalidURL(rawBase)
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
