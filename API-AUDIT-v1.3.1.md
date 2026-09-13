# Mihomo Core Manager v1.3.1 API 巡查与修订记录

> 本文件对应 **v1.3.1 / build 1301** 的原地 hotfix。未升级 VERSION、BUILD_NUMBER、依赖基线或最低系统版本。
>
> 完整接口、端口、认证、systemd/SSH 命令和失败回退说明见：`INTERFACE-IMPLEMENTATION-v1.3.1.md`。
>
> 官方对照：Mihomo API <https://wiki.metacubex.one/en/api/>；Mihomo systemd service <https://wiki.metacubex.one/en/startup/service/>（巡查日期：2026-09-13）。

## 本轮结论

v1.3.1 的远端控制链调整为**按能力选择首选实现 + 按网络条件选择传输路径**，而不是默认依赖 Core 服务面板：

- Core 在线数据与 Core 内部控制：优先 **Mihomo Controller API**。
- Linux 服务生命周期：优先服务器现有 **`mihomo.service` / systemd**。
- Core 服务面板：作为生命周期/日志的**备选与容错**，并继续承担没有 Core/systemd 等价实现的订阅事务与整套项目升级。
- GoWebUI：Controller/Management 端口客户端直连失败时，自动尝试 **SSH 到服务器 → curl 原 URL → curl `127.0.0.1:原端口`**；接口语义不变，只改变传输路径。

最终关键优先级：

| 功能 | 优先级 |
|---|---|
| 状态 | Controller `/version` + `/connections` → `systemctl show mihomo.service` → `/api/status` |
| 启动 / 停止 | `systemctl start/stop mihomo.service` → `/api/action` |
| 重启 | Controller `POST /restart` → `systemctl restart mihomo.service` → `/api/action` |
| 配置重载 | Controller `PUT /configs?force=true` → `systemctl reload mihomo.service` → `/api/action` |
| 历史日志 | `journalctl -u mihomo.service` → `/api/logs` |
| 运行模式 / 代理 / provider / 选择 / 测速 | Mihomo Controller API；直连失败时同 API over SSH |
| 订阅事务 | Core 服务面板 `/api/subscriptions`；直连失败时 Management over SSH |
| 三组件项目升级 | Core 服务面板 `/api/project-update/*`；直连失败时 Management over SSH |

## Controller API 巡查

| 功能 | 方法 / 接口 | v1.3.1 实现 |
|---|---|---|
| Core 在线/版本 | `GET /version` | 直接 Core API |
| 连接数/累计流量/内存 | `GET /connections` | 直接 Core API |
| 运行模式读取 | `GET /configs` | 直接 Core API |
| 运行模式切换 | `PATCH /configs` | 直接 Core API |
| config.yaml 热重载 | `PUT /configs?force=true` + `{path,payload}` | **Core → systemd reload → 面板** |
| 重启 Core | `POST /restart` + `{path,payload}` | **Core → systemd restart → 面板** |
| 代理/策略组快照 | `GET /proxies`, `GET /group` | 直接 Core API |
| Proxy Provider | `GET /providers/proxies` | 直接 Core API；合并 provider-only 叶子节点 |
| 策略组测速 | `GET /group/{name}/delay` | 直接 Core API；组名按单一路径段转义 |
| 代理选择 | `PUT /proxies/{name}` | 直接 Core API；名称按单一路径段转义 |

官方存在但本轮不直接替换的 `/logs`、`/traffic`、`/memory`、`/upgrade`，原因详见接口说明文件：当前页面需要历史 journal，状态模型已经基于 `/connections`，项目升级则包含 Core 之外的 MetaCubeXD 与面板自身。

## `mihomo.service` 巡查

服务器端 unit 固定为 `mihomo.service`。macOS 客户端通过 `/usr/bin/ssh` 非交互执行固定命令：

- 状态：`systemctl show mihomo.service ...`
- 启动：`systemctl start mihomo.service`
- 停止：`systemctl stop mihomo.service`
- 重启：`systemctl restart mihomo.service`
- 重载：`systemctl reload mihomo.service`
- 日志：`journalctl -u mihomo.service -n N --no-pager -o cat`

非 root SSH 用户的修改型操作使用 `sudo -n`；失败自动进入面板回退。状态解析使用 `systemctl show` 的属性输出，不解析面向人的 `systemctl status` 文本。

Profile 新增可选字段 `systemdSSHTarget` / `systemdSSHPort` / `systemdIdentityFile`。旧配置缺少字段时仍可解码。GoWebUI 对 LAN Profile 在 target 留空时会从 Management/Controller URL 自动推断 SSH host；显式 `user@host` 始终优先，公共域名不自动探测。

## 端口巡查

- **Controller：** 不自动补 9090。`9090` 仅为 UI 示例/测试；实际端口完全来自 `coreControllerURL`。
  - 服务端 `external-controller: 0.0.0.0:9090` 是合法监听方式，客户端仍必须使用服务器真实 IP/域名而不是 `0.0.0.0`；直连成功时优先直连，失败才进入 SSH/loopback 容错。
  - 因为 `0.0.0.0` 会把 Controller 暴露到所有 IPv4 网卡，审计要求启用 Controller Secret，并用防火墙限制可信来源。
- **systemd SSH：** 默认 22，可配置 1...65535；这是本轮唯一主动提供默认远端端口的管理通道。
- **Management：** 不自动补 29090。`29090` 仅为 UI 示例；实际端口来自 `managementURL`。
- **MetaCubeXD：** 使用 URL 自带端口，不猜测。
- **GoWebUI local runtime：** 只监听 `127.0.0.1:0`，由 OS 分配随机空闲端口，并要求本地 token。
- **Mihomo 代理数据端口：** `/configs` 中的 `port` / `socks-port` / `mixed-port` / redir / tproxy / listener 不作为本 App 的控制端口。
- **测速目标：** URL 作为参数交给 Core，由 Core 在服务器侧发起请求，客户端不额外直连测试目标端口。
- **SSH 本机 HTTP 回退：** 不新增/猜测 9090、29090 等业务端口，只把用户 URL 中已有的 scheme、port、path/query 原样带到服务器；原 URL 无法连接时仅把 host 换成 `127.0.0.1`。

## Core 服务面板保留项

Core 服务面板现在是 fallback / transaction backend：

- `/api/status`：Controller + systemd 均失败后的状态回退。
- `/api/action`：systemd/Core API 对应生命周期失败后的回退。
- `/api/logs`：journal 失败后的历史日志回退；Management 直连失败可 SSH 本机访问。
- `/api/subscriptions`：保留订阅 URL 持久化、renderer、config 校验/回滚事务；Management 直连失败可 SSH 本机访问。
- `/api/project-update/*`：保留 Core + MetaCubeXD + 面板三组件升级语义；Management 直连失败可 SSH 本机访问。

## GoWebUI 本地桥接

`/local/*` 仍只绑定随机 loopback 端口并要求 `X-Mihomo-Local-Token`。与本轮有关的映射：

- `/local/status` → Controller → systemd → Management
- `/local/action` → restart 时 Core → systemd → Management；start/stop 时 systemd → Management
- `/local/reload-config` → Core `/configs` → systemd reload → Management
- `/local/logs` → journal → Management
- 代理相关 `/local/proxy-*` → Mihomo Controller；网络不可达时同 API over SSH
- `/local/subscriptions`、`/local/update/*` → Management；网络不可达时同面板接口 over SSH

## 回归测试新增

- `TestSystemdSSHArgumentsUseExplicitPortAndIdentity`
- `TestStartPrefersSystemdBeforeManagementPanel`
- `TestRestartFallsBackFromControllerToSystemdBeforeManagement`
- `TestStatusFallsBackFromControllerToSystemdBeforeManagement`
- `TestLogsPreferSystemdJournalBeforeManagement`
- `TestEffectiveSystemdSSHTargetInfersLANManagementHost`
- `TestControllerHTTPFallsBackThroughSSHToServerLoopback`
- `TestManagementEndpointsFallBackThroughSSHToServerLoopback`
- `TestProxySelectFallsBackThroughSSHWhenControllerPortIsBlocked`
- `TestLogsInferSSHHostAndPreferJournal`

既有 Controller Secret、`/configs`、代理/provider、路径转义、测速、代理切换、Cloudflare/LAN 回退、订阅安全重启等测试继续保留。

最终构建前要求执行：`go test ./...`、`go test -race ./...`、`go vet ./...`、Swift parse/type gates、WebUI JavaScript 检查、`scripts/validate-source.py`、release lock/source manifest 检查及 portable installer 校验。
