import Foundation

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
