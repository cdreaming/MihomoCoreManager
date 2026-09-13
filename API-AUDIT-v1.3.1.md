# Mihomo Core Manager v1.3.1 API 巡查与修订记录

> 本文件对应 **v1.3.1 / build 1301** 的原地 hotfix。未升级 VERSION、BUILD_NUMBER、依赖基线或最低系统版本。
>
> Mihomo API 对照来源：<https://wiki.metacubex.one/api/>（巡查日期：2026-09-13）。

## 结论

v1.3.1 的基础 Core 管理路径已以 Mihomo Controller API 为主。此次巡查新增一处明确可替换项：**重启 Core 改为优先调用 Mihomo `POST /restart`**；如果 Controller 不可用且已配置可选管理面板，则兼容回退原 `/api/action`。

下列功能继续保留管理面板 API，不强行替换：

- **启动 / 停止 Core**：Core 停止后自身 Controller API 不存在，无法自启动。
- **订阅 URL 写入与配置渲染事务**：当前产品语义是“保存订阅源 → 生成/校验 config.yaml → 热重载/安全重启”。Mihomo 的 provider `PUT` 只刷新既有 provider，不等价于编辑订阅源与渲染配置。
- **最近 N 行历史服务日志**：Mihomo `/logs` 是 GET/WS 实时流；当前页面语义是读取已有的 bounded history，因此继续使用管理面板历史日志接口。
- **项目升级**：当前功能一次协调 Mihomo Core + MetaCubeXD + Core 管理面板；Mihomo `/upgrade` 只覆盖 Core，本次不改变产品语义。

## 远端接口逐项巡查

| 功能 | 优先实现 | 方法 / 接口 | 结果 |
|---|---|---|---|
| Core 在线/版本 | Mihomo Core | `GET /version` | 保留，直接 Core API |
| 连接数/累计流量/内存 | Mihomo Core | `GET /connections` | 保留，直接 Core API |
| 运行模式读取 | Mihomo Core | `GET /configs` | 保留，直接 Core API |
| 运行模式切换 | Mihomo Core | `PATCH /configs` | 保留，直接 Core API |
| config.yaml 热重载 | Mihomo Core | `PUT /configs?force=true` + `{path,payload}` | 保留，直接 Core API；无 Controller 的旧配置回退管理面板 |
| 重启 Core | Mihomo Core | `POST /restart` + `{path,payload}` | **本次改为优先 Core API**；失败时兼容回退管理面板 |
| 代理/策略组快照 | Mihomo Core | `GET /proxies`, `GET /group` | 保留，直接 Core API |
| Proxy Provider 信息 | Mihomo Core | `GET /providers/proxies` | 保留，直接 Core API；用于合并 provider-only 叶子节点 |
| 策略组测速 | Mihomo Core | `GET /group/{name}/delay` | 保留，直接 Core API；组名按单一路径段转义 |
| 代理选择 | Mihomo Core | `PUT /proxies/{name}` | 保留，直接 Core API；名称按单一路径段转义 |
| 启动/停止 | 管理面板 | `POST /api/action` | 保留；Core 无自启动/自停止等价接口 |
| 订阅读取/写入 | 管理面板 | `GET/POST /api/subscriptions` | 保留；承担订阅源写入与 renderer 事务 |
| 历史日志 | 管理面板 | `GET /api/logs?lines=N` | 保留；与 Mihomo `/logs` 实时流语义不同 |
| 项目升级检查/执行/日志 | 管理面板 | `/api/project-update/*` | 保留；协调 Core + MetaCubeXD + 管理面板，不等价于 Core `/upgrade` |
| 状态兼容回退 | 管理面板 | `GET /api/status` | 仅在 Controller 不可用且旧配置仍有管理面板时使用 |

### 认证与 URL 规则

- Mihomo Controller 使用 `Authorization: Bearer <secret>`。
- Controller Secret 独立保存；**留空时保持 v1.3.0 兼容行为，复用 Management Secret**。
- Controller URL 必须是 API 根地址；`/ui/` 会被剥离，不自动猜 9090 端口。
- 明文 HTTP 仍受每个 Profile 的“允许不安全 HTTP”开关约束。
- GoWebUI 对私网、loopback、link-local、Bonjour `.local`、`.lan`、`.home.arpa` 与单标签 LAN 主机继续绕过环境代理。

## GoWebUI 本地桥接接口

GoWebUI 的 `/local/*` 只绑定到随机的 `127.0.0.1` 端口，并要求 `X-Mihomo-Local-Token`；它们是窗口/状态栏到本地 Go runtime 的桥接接口，不是远端管理协议。

- Profile：`/local/profiles`, `/local/profile/save`, `/local/profile/select`, `/local/profile/delete`
- 状态与 Core 动作：`/local/status`, `/local/action`, `/local/reload-config`
- 代理：`/local/proxy-mode`, `/local/proxy-groups`, `/local/proxies`, `/local/proxy-menu-cache`, `/local/proxy-delay`, `/local/proxy-delay-async`, `/local/proxy-select`, `/local/proxy-select-async`
- Secret：`/local/controller-secret/clear`, `/local/management-secret/clear`
- 订阅/日志/升级：`/local/subscriptions`, `/local/logs`, `/local/update/check`, `/local/update/apply`, `/local/update/log`
- App 辅助：`/local/metacubexd`, `/local/menu-preferences`, `/local/open-url`, `/local/clipboard`, `/local/quit`

## v1.3.0 “设置” → v1.3.1 “服务设置” 对照

此次不把标签页名称改回“设置”。v1.3.1 继续使用 **“服务设置”**，只补回 v1.3.0 中实际存在但 GoWebUI 页面遗漏的设置能力：

- 状态栏：显示图标 / 运行状态 / 实时网速 / 仅显示图标。
- **状态刷新间隔：1 / 1.2 / 2 / 5 / 10 秒。** Go runtime 后台轮询和 WebUI 概览刷新共同使用该值。
- **默认日志行数：50 / 100 / 200 / 300。** 打开运行日志时使用该默认值。
- Secret 的明确粘贴/清除操作。
- Controller Secret 留空复用 Management Secret 的 v1.3.0 兼容说明。

SwiftUI 原生页面原本仍保留刷新间隔和默认日志行数，因此本次主要修复其兼容提示与重启实现；GoWebUI 则补回缺失的两个设置控件及持久化逻辑。

## 测试覆盖

本次新增/扩展 Go 回归测试：

- `TestDirectRestartPrefersMihomoCoreAPI`：验证 `POST /restart`、Controller Bearer Secret、`{path,payload}` 请求体，并确保不调用管理面板。
- `TestRestartFallsBackToManagementWhenControllerRestartFails`：验证 Controller 重启失败后兼容回退 `/api/action`。
- `TestMenuPreferences`：验证状态刷新间隔与默认日志行数持久化；同时验证状态栏原生进程只更新三个布尔开关时不会覆盖这两个设置。
- 既有测试继续覆盖 Controller Secret 优先/无认证、`/configs` 模式切换、代理列表/provider 合并、路径转义、组测速、代理切换、Cloudflare/LAN 回退、订阅热重载超时后的安全重启等路径。

最终构建前执行 `go test`, `go test -race`, `go vet`, `scripts/validate-source.py` 与 release preflight/build 检查；结果记录在最终交付说明中。
