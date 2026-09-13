# MihomoManager v1.3.1 接口与端口实现说明

> 适用版本：**MihomoManager v1.3.1 / build 1301**。
>
> 本文件是 v1.3.1 原地修复的接口契约，不代表升级到新版本。目标是让客户端在能力重叠时始终优先使用 **Mihomo Core Controller API** 和服务器现有的 **`mihomo.service` systemd unit**，仅把 **Core 服务面板**保留为兼容、事务型能力和故障回退。

## 1. 总体优先级

不同操作的“第一选择”必须按操作本身的能力边界决定，而不是把所有请求统一发给同一个后端：

| 功能 | 第一选择 | 第二选择 | 最终备选 | 说明 |
|---|---|---|---|---|
| Core 在线状态 / 版本 / 连接统计 | Mihomo Controller | `mihomo.service` 状态 | Core 服务面板 `/api/status` | 主链保持 `Controller -> systemd -> Management`；Controller/systemd 成功时再以 30 秒慢速 Management 元数据补齐 Core 面板/MetaCubeXD 版本，不覆盖 Core 权威版本 |
| 启动 Core | `mihomo.service` | Core 服务面板 `/api/action` | 无 | 已停止的 Core 不可能通过自己的 HTTP API 启动自己 |
| 停止 Core | `mihomo.service` | Core 服务面板 `/api/action` | 无 | 生命周期交给服务管理器最可靠 |
| 重启 Core | Mihomo `POST /restart` | `systemctl restart mihomo.service` | Core 服务面板 `/api/action` | Core 在线时优先原生 API；API 失效再切到 systemd |
| 重载 `config.yaml` | Mihomo `PUT /configs?force=true` | `systemctl reload mihomo.service`（仅 `CanReload=yes`） | Core 服务面板 `/api/action` | v4.0.1 默认 unit 无 `ExecReload`；检测为不可 reload 时直接跳过 systemd，避免假成功/无效调用 |
| 最近 N 行服务日志 | `journalctl -u mihomo.service` | 面板 `/api/logs`（直连失败可经 SSH 本机端口） | 无 | Mihomo `/logs` 是实时流，不等价于历史 journal |
| 运行模式读取/切换 | Mihomo `/configs` | 无 | 无 | 纯 Core 运行态能力 |
| 代理列表 / 策略组 / provider | Mihomo `/proxies`、`/group`、`/providers/proxies` | 同一 Core API 经 SSH/服务器本机端口 | 无 | 语义仍是 Core API；SSH 只是传输容错 |
| 代理选择 / 策略组测速 | Mihomo `/proxies/{group}`、`/group/{group}/delay` | 同一 Core API 经 SSH/服务器本机端口 | 无 | 测速目标 URL 由 Core 访问，客户端只访问 Controller |
| 订阅读取/写入与配置渲染事务 | Core 服务面板 `/api/subscriptions` | 同一面板接口经 SSH/服务器本机端口 | 无 | 当前产品语义包含订阅源持久化、渲染、校验、回滚；不是 Mihomo provider refresh 的等价物 |
| 项目升级（Core + MetaCubeXD + 面板） | Core 服务面板 `/api/project-update/*` | 同一面板接口经 SSH/服务器本机端口 | 无 | Mihomo `/upgrade` 只覆盖 Core，不能原样替代整套项目升级 |
| 打开 MetaCubeXD | 显式 LAN MetaCubeXD URL | LAN Management 主机 + `/api/status` 返回端口 | 显式/面板公网 URL | 对齐 v4.0.1 的 LAN 95% 优先；不猜 `:29091`，只使用部署元数据明确返回的端口 |

### 关键原则

1. **Controller 能完成的 Core 内部操作，优先 Controller。**
2. **服务生命周期由 `mihomo.service` 优先承担。** 尤其是启动和停止，不再要求 Core 服务面板必须在线。
3. **Core 服务面板不删除。** 它仍是兼容回退，并继续提供订阅事务、历史日志回退和三组件项目升级等没有一一等价 Core API 的产品能力。
4. **不猜业务端口。** Controller、Management、MetaCubeXD 均保留用户配置 URL 的显式端口；只有 SSH 默认 22。省略 scheme 时 LAN/private 推断为 `http://`，公共主机推断为 `https://`；显式 scheme 永远优先。
5. **SwiftUI / GoWebUI 的端口容错不等于改端口。** 直连 Controller/Management 发生无路由、拒绝连接、超时或临时网关故障时，若存在可用 SSH 路径，会在服务器侧先请求原 URL；若服务器自身也无法访问该地址，再把同一 scheme/port/path 改为 `127.0.0.1` 重试。
6. **监听地址不是客户端地址。** `0.0.0.0` / `::` 允许出现在服务器 `external-controller` 监听配置中，但 Manager 会拒绝把它们当 Controller/Management/MetaCubeXD 客户端目标；必须填写真实 LAN IP、主机名或公网域名。
7. **Secret 双向复用。** Controller Secret 优先使用其独立值，未设置时复用 Management Secret；Management Secret 同理反向复用 Controller Secret。v4.0.1 受保护 Management API 可直接接受同一 Core Secret 的 Bearer 认证。

## 2. Mihomo Controller API

### 2.1 URL 与认证

Profile 字段：

- `coreControllerURL`：Mihomo External Controller API 根地址。
- `Controller Secret`：优先使用独立 Controller Secret；为空时复用 Management Secret。反过来，Management Secret 为空时也复用 Controller Secret，避免同一 v4.0.1 Core Secret 被要求重复保存。
- 请求头：`Authorization: Bearer <secret>`（Secret 非空时）。
- `coreControllerURL` 可以直接粘贴 `/ui/`、`/Ui/`、`/version`、`/connections`、`/configs` 等地址；客户端按**路径段大小写不敏感**识别 `ui`，仅剥离已知尾部，保留反向代理前置路径与显式端口。例如 `https://host/rev/Ui/#/proxies` → `https://host/rev`。
- **不会自动补 `:9090`。** URL 未写端口时按 URL 标准使用 HTTP 80 / HTTPS 443；非默认端口必须由用户显式写入。
- 服务器端可以把 Mihomo `external-controller` 监听为 `0.0.0.0:9090`，这表示在所有 IPv4 网卡监听；**客户端 Profile 不得填写 `0.0.0.0`**，应填写服务器真实可达地址，例如 `http://192.168.8.202:9090`。直连可达时 GoWebUI 不会进入 SSH 回退。
- `0.0.0.0:9090` 会扩大 Controller 暴露面。必须配置强 `secret`，并建议用主机防火墙仅允许可信 LAN/VPN 来源访问 9090，避免公网端口映射。
- 明文 `http://` 仍受 Profile 的“允许不安全 HTTP”设置约束。若用户省略 scheme，LAN/private 主机推断为 HTTP，公共主机推断为 HTTPS；不会同时猜业务端口。

### 2.2 当前直接调用的 Core 接口

| 方法 | 路径 | 客户端用途 | 回退 |
|---|---|---|---|
| `GET` | `/version` | Core 在线探测、版本读取 | status 场景失败后转 systemd，再转面板 |
| `GET` | `/connections` | 累计上传/下载、连接数、内存快照 | 单项失败不阻止 `/version` 判定在线 |
| `GET` | `/configs` | 读取运行模式等运行配置 | 无 |
| `PATCH` | `/configs` | 切换 `rule/global/direct` | 无 |
| `PUT` | `/configs?force=true` | 以 `{path, payload}` 重载 Profile 配置文件 | `systemctl reload`（仅 `CanReload=yes`）→ 面板 reload |
| `POST` | `/restart` | 原生重启 Core，body 使用 `{path, payload}` | `systemctl restart` → 面板 restart |
| `GET` | `/proxies` | 代理 / 策略组快照 | 无 |
| `GET` | `/group` | 动态策略组元数据与顺序 | 无 |
| `GET` | `/providers/proxies` | 合并 provider-only 叶子节点、测速信息 | 无 |
| `GET` | `/group/{name}/delay` | 策略组测速 | 无 |
| `PUT` | `/proxies/{name}` | 选择策略组当前代理 | 无 |

`{name}` 始终按**单一路径段**进行 URL 编码，避免组名中的空格、斜杠等字符改变接口路径结构。

### 2.3 SwiftUI / GoWebUI：Controller HTTP-over-SSH 传输容错

Controller 的**接口语义不变**，仍然是 Mihomo Core API。两套实现均仅在客户端无法直接到达配置端口时切换传输路径：

```text
macOS 直连 http(s)://<controller-host>:<port>/<path>
  ↓ 网络不可达 / connection refused / timeout / 临时网关错误
SSH 到 Mihomo 服务器
  ↓
服务器 curl 原 Controller URL
  ↓ curl 无法建立连接
服务器 curl http(s)://127.0.0.1:<同一端口>/<同一路径>
```

这会覆盖 `/version`、`/connections`、`/configs`、`/proxies`、`/group`、`/providers/proxies`、策略组测速和代理选择。因此例如客户端访问 `192.168.9.202:9090` 报 `no route to host`，但 Core 实际只监听服务器 `127.0.0.1:9090` 时，代理页和切换操作仍可工作。

写操作（如 `PUT /proxies/{group}`）**不会在收到明确 HTTP 状态后再换第二个目标重放**；只有 curl 本身未建立 HTTP 连接时才尝试 loopback，避免重复提交。请求 body 经 SSH stdin 传输，避免大订阅/配置内容进入本地 argv。

### 2.4 没有直接替换的官方接口

Mihomo 官方还提供 `/logs`、`/traffic`、`/memory`、`/upgrade` 等接口。v1.3.1 没有为了“接口越多越好”而机械替换现有语义：

- `/logs` 是 GET/WS 实时日志流；当前“运行日志”页面要求“最近 N 行已有日志”，因此优先读取 systemd journal。
- `/traffic` 和 `/memory` 是实时流接口；当前轮询模型可从 `/connections` 获得累计流量、连接与内存，并在本地计算速率，不额外维持长连接。
- `/upgrade` 只升级 Mihomo Core；现有“项目升级”同时协调 Core、MetaCubeXD 和服务面板，所以继续由项目面板执行。

## 3. `mihomo.service` / systemd 实现

### 3.1 为什么通过 SSH

macOS 客户端与远端 Linux systemd 不共享本地 D-Bus/socket，因此不能把远端 `systemctl` 当成本机命令执行。v1.3.1 使用 macOS 自带的 `/usr/bin/ssh` 作为远端传输层，在服务器上执行**固定的** `mihomo.service` 命令。

Profile 新增兼容字段：

- `systemdSSHTarget`：例如 `root@192.168.1.2`。**两套实现留空时都会从 LAN `managementURL`，其次从 LAN `coreControllerURL` 自动推断 host**；如服务器 SSH 用户名不同，应显式填写 `user@host`。
- `systemdSSHPort`：SSH 端口，默认 `22`，允许 `1...65535`。
- `systemdIdentityFile`：可选私钥路径；留空时使用系统 ssh-agent / SSH 默认行为。

旧 v1.3.1 Profile 不含这些字段也能正常解码。两套实现对 RFC1918 风格 LAN Profile 可自动推断 SSH 主机；公共域名与 loopback 不会被自动探测 SSH。

### 3.2 SSH 安全与非交互参数

两套实现（SwiftUI / GoWebUI）的 systemd 命令与 SSH 安全参数使用相同策略：

```text
/usr/bin/ssh
  -o BatchMode=yes
  -o ConnectTimeout=4
  -o ConnectionAttempts=1
  -o StrictHostKeyChecking=accept-new
  -o LogLevel=ERROR
  -p <configured-port>
  [-i <identity-file>]
  -- <user@host> <fixed-remote-command>
```

约束：

- 不弹 SSH 密码输入框，也不把 SSH 密码保存进 App。
- `systemdSSHTarget` 不允许以 `-` 开头，也不允许包含空白字符，避免它变成额外 SSH 参数。
- unit 名固定为 **`mihomo.service`**，不接受任意 shell unit/命令字符串。
- action 只允许 `start / stop / restart / reload` 四个白名单 verb。
- 日志行数先夹紧到 `10...300` 后再拼入固定命令。
- SwiftUI 与 GoWebUI 都对 SSH 子进程设 10 秒总超时；连接本身另有 4 秒 SSH ConnectTimeout。
- 非 root SSH 用户执行生命周期操作时使用 `sudo -n`，服务器需预先配置对应的免密 sudo 权限；失败会进入面板回退。

### 3.3 systemd 状态

机器可解析状态使用：

```bash
LC_ALL=C systemctl show mihomo.service --no-pager \
  --property=LoadState \
  --property=ActiveState \
  --property=SubState \
  --property=UnitFileState \
  --property=MainPID \
  --property=FragmentPath
```

解析后映射为 App 的 `ServiceStatus`：

- `ActiveState` / `SubState` → 运行状态。
- `UnitFileState` → 是否 enabled 以及 unit file 状态。
- `MainPID` → PID。
- `FragmentPath` → 实际加载的 service 文件路径（UI 的 `Unit` 字段）。

若 `LoadState=not-found`，视为该服务器没有可用的 `mihomo.service`，继续尝试 Core 服务面板回退。

### 3.4 生命周期命令

root 用户（实际执行 verb 仍只来自白名单）：

```bash
systemctl start|stop|restart mihomo.service
# reload 仅在 systemctl show ... CanReload=yes 时执行
systemctl reload mihomo.service
```

为了与 v4.0.1 管理面板一致，Manager 直接执行 `start` 或 `restart` 前会先 best-effort `systemctl disable mihomo.service`，保持该部署“手工启动但不开机自启”的策略；失败不会阻止本次启动/重启。

非 root 用户：

```bash
sudo -n systemctl start|stop|restart mihomo.service
# reload 同样先确认 CanReload=yes
sudo -n systemctl reload mihomo.service
```

v4.0.1 默认 unit 没有 `ExecReload`。因此 Manager 不再把“`systemctl reload` 命令被调用过”当作正确实现：会先读取 `CanReload`，若为 `no`/空则直接进入 Management `/api/action` 的 reload 兜底。

App 不直接编辑 `/etc/systemd/system/mihomo.service` 内容；systemd 始终是 unit 文件及其启停状态的权威来源。这样可以兼容服务器已有的 `User=`, `ExecStart=`, `WorkingDirectory=`, `Restart=` 等本机配置，避免客户端复制/覆盖服务文件造成漂移。

### 3.5 历史日志

优先命令：

```bash
journalctl -u mihomo.service -n <10...300> --no-pager -o short-iso
```

若普通用户无 journal 读取权限，再尝试：

```bash
sudo -n journalctl -u mihomo.service -n <10...300> --no-pager -o short-iso
```

若 SSH / journal 均失败且已配置 Management，则回退 `/api/logs?lines=N`。两套实现对这个 Management 请求同样应用 HTTP-over-SSH 本机端口容错；若两层都失败，错误信息会同时保留 journal/systemd 与面板失败原因。

## 4. Core 服务面板兼容接口

Management URL 是**可选备选接口**，不再是所有 Core 操作的首选入口。Management Secret 继续保存于 macOS Keychain。

| 方法 | 面板路径 | 用途 | 触发条件 |
|---|---|---|---|
| `GET` | `/api/status` | 状态兼容 | Controller 与 systemd 都不可用 |
| `POST` | `/api/action` | start/stop/restart/reload | systemd 或 Core API 的对应路径失败 / 未配置 |
| `GET` / `POST` | `/api/subscriptions` | 读取、保存订阅并执行 renderer 事务 | 当前唯一实现 |
| `GET` | `/api/logs?lines=N` | 最近 N 行日志 | journal 回退 |
| `GET` | `/api/project-update/check` | 检查三组件项目更新 | 当前唯一实现 |
| `POST` | `/api/project-update/apply` | 执行三组件项目更新 | 当前唯一实现 |
| `GET` | `/api/project-update/log` | 项目升级日志 | 当前唯一实现 |

**不会自动补 `:29090`。** 示例端口只出现在 UI placeholder/文档中，实际网络请求完全使用用户填写的 Management URL。Management URL 也拒绝 `0.0.0.0` / `::` 这种监听地址。

Management URL 若误填 `/api/status`、`/api/action`、`/api/logs`、`/api/subscriptions`、`/api/project-update/check|apply|log` 或 `/healthz`，保存时会仅剥离这些**已知末尾 endpoint**，保留其前面的反向代理前缀、scheme 和显式端口。Controller 的 `/ui/` 处理同样按路径段大小写不敏感，因此 `/Ui/`、`/prefix/ui/` 都能正确还原 API 根路径。Management 还兼容用户直接粘贴 `/api/login` / `/api/logout`；桌面 App 不需要建立 Cookie 会话，只用 Bearer Secret。

参考 v4.0.1 面板的 `/api/login` 与 `/api/logout` 是浏览器会话入口；受保护 API 本身支持 `Authorization: Bearer <Core Secret>`。MihomoManager 保存 Management Secret 于 Keychain，并直接对业务 API 使用 Bearer，不额外建立浏览器 Cookie 会话。`/healthz` 仅是无鉴权 liveness，不替代包含业务状态字段的 `/api/status`。

两套实现对 Management 接口都有与 Controller 相同的**传输容错**：客户端直连失败后，经 SSH 在服务器侧请求原 URL；连接仍失败时再请求 `127.0.0.1:<Management 原端口>`。因此 `/api/subscriptions`、`/api/logs`、`/api/project-update/check|apply|log` 即使只绑定 localhost，也不要求把 29090 暴露到客户端 LAN。

## 5. 端口巡查结果

### 5.1 客户端会主动连接的网络端点

| 端点 | 端口来源 | 是否有默认值 | 说明 |
|---|---|---|---|
| Mihomo Controller | `coreControllerURL` | URL 标准的 HTTP 80 / HTTPS 443；App 不补 9090 | 推荐控制面；9090 只是常见示例 |
| `mihomo.service` SSH | `systemdSSHPort` | **22** | SwiftUI / GoWebUI 可从 LAN Management/Controller host 推断 SSH 主机；端口仍固定来自此字段 |
| Core 服务面板 | `managementURL` | URL 标准 80 / 443；App 不补 29090 | 备选 / 事务接口 |
| MetaCubeXD | `metaCubeXDURL` 或兼容返回 URL | URL 自带 | 由系统打开浏览器/Web 内容，不猜端口 |
| GoWebUI 本地 runtime | `127.0.0.1:0` | **OS 随机空闲高位端口** | 只监听 loopback，启动时由内核分配，不对 LAN 暴露 |

### 5.2 不属于客户端控制端口的 Mihomo 端口

Mihomo `/configs` 返回的 `port`、`socks-port`、`mixed-port`、redir/tproxy/listener 等属于**代理数据平面**。本 App 不拿这些端口作为 Controller、systemd 或 Management 控制通道，也不会根据它们改写后端 URL。

策略组测速中的测试 URL 也是作为查询参数交给 Mihomo Controller，由 **Mihomo Core 在服务器侧发起测试**；macOS 客户端不会为了测速额外直连测试站点的端口。

### 5.3 硬编码端口检查

源码巡查确认：

- `9090` 仅存在于 Controller URL 示例、测试和“不自动补 9090”的说明；SSH loopback 回退**保留用户配置的原端口**，不会凭空补 9090。
- `29090` 仅存在于 Management URL 示例/测试；SSH loopback 回退同样只保留 URL 已有端口。
- `22` 是启用 systemd SSH 后的明确默认 SSH 端口。
- `127.0.0.1:0` 是 GoWebUI 本地桥接监听，`0` 表示由系统分配临时端口。
- 测试中的 `127.0.0.1:1`、`:12345` 等仅为单元测试夹具，不进入发布运行逻辑。

因此 v1.3.1 不会因为“常见端口”而偷偷改写用户配置。

## 5.4 v4.0.1 三层回退矩阵（本轮复核）

本轮把“默认 / 备选 / 兜底”落实到两种不同维度，避免把所有接口机械塞给同一后端：

- **Core runtime 类：** Controller API → systemd/SSH → Management `/api/status|action`。其中状态的面板/XD 版本由 Management 以 30 秒慢速元数据补齐，Controller Core 版本仍是权威值。
- **Controller-only 类（模式、代理、provider、测速、选择）：** macOS 直连 Controller → SSH 到服务器后 curl 原 URL → 同 scheme/port/path 改 host 为 `127.0.0.1`。这三层都调用同一个 Mihomo API，不改变业务语义。
- **Management-only 类（订阅事务、项目升级）：** macOS 直连 Management → SSH curl 原 URL → SSH curl `127.0.0.1:<原端口>`。明确收到 HTTP 状态后不再重放写请求。
- **systemd SSH 目标：** Profile 显式 `systemdSSHTarget` → LAN Management host 推断 → LAN Controller host 推断。公共域名、loopback 与 wildcard listener 不自动拿来做 SSH 目标。
- **MetaCubeXD 打开地址：** 显式 LAN URL → LAN Management host + `/api/status` 返回的 standalone port → 显式/状态公网 URL。没有部署端口元数据时绝不凭空补 `29091`。

这套分层同时适用于 SwiftUI 与 GoWebUI；浏览器 CORS/PNA 是 MetaCubeXD 网页直连 Core 时的服务器配置问题，**原生 Swift URLSession 与本地 Go runtime 本身不受浏览器 CORS 限制**。

## 6. GoWebUI 本地桥接接口

GoWebUI 仍在 `127.0.0.1:0` 创建本地 HTTP runtime，并要求 `X-Mihomo-Local-Token`。这些 `/local/*` **不是远端服务器接口**，只是 WebKit / 状态栏与本地 Go runtime 之间的桥接。

| 本地接口 | 作用 | 远端实现 |
|---|---|---|
| `/local/status` | 状态快照 | Controller → systemd → Management；Controller/systemd 成功时慢速合并 Management 的面板/XD 版本元数据 |
| `/local/action` | 生命周期动作 | restart: Core → systemd → Management；start/stop: systemd → Management |
| `/local/reload-config` | 配置重载 | Core `/configs` → systemd reload（仅 `CanReload=yes`）→ Management |
| `/local/logs` | 最近 N 行日志 | journal → Management（Management 可 HTTP-over-SSH） |
| `/local/proxy-mode` | 运行模式 | Core `/configs` |
| `/local/proxy-groups` | 策略组 | Core `/group` + `/proxies`；直连失败可 HTTP-over-SSH |
| `/local/proxies` | 代理快照 | Core `/proxies` + `/providers/proxies`；直连失败可 HTTP-over-SSH |
| `/local/proxy-delay*` | 测速 | Core `/group/{name}/delay`；直连失败可 HTTP-over-SSH |
| `/local/proxy-select*` | 代理选择 | Core `/proxies/{name}`；直连失败可 HTTP-over-SSH |
| `/local/subscriptions` | 订阅事务 | Management `/api/subscriptions`；直连失败可 HTTP-over-SSH |
| `/local/update/*` | 项目升级 | Management `/api/project-update/*`；直连失败可 HTTP-over-SSH |
| `/local/profiles`、`/local/profile/*` | 本地 Profile | 本地 settings + Keychain |
| `/local/*-secret/clear` | 清除 Secret | macOS Keychain |
| `/local/menu-preferences` | 状态栏 / 刷新 / 日志偏好 | 本地 settings |
| `/local/metacubexd`、`/local/open-url` | 打开 Dashboard / URL | 本机系统打开 |
| `/local/clipboard` | 显式粘贴辅助 | 本机剪贴板 |
| `/local/quit` | 退出 GoWebUI runtime | 本机进程 |

## 7. 两套客户端实现保持一致

### SwiftUI

主要实现位置：

- `MihomoCoreManager/Models.swift`：Profile 的 systemd SSH 字段和 ServiceStatus unit path。
- `MihomoCoreManager/API/MihomoAPIClient.swift`：Controller / systemd / Management 优先级与回退。
- `MihomoCoreManager/AppModel.swift`：能力判断、动作分发。
- `MihomoCoreManager/Views/SettingsView.swift`：`mihomo.service（推荐）` 与原有 `扩展管理（可选）` 配置；后者明确作为 Core 服务面板兜底。
- `MihomoCoreManager/Views/CoreView.swift`、`MenuBarView.swift`：按钮可用性根据 Controller/systemd/Management 能力判断。

### GoWebUI portable

主要实现位置：

- `portable-runtime/main.go`：`effectiveSystemdSSHTarget`、`systemdSSHArgs`、`runSystemdSSH`、`remoteRequestWithSSHFallback`、`remoteRequestViaSSH`、`systemdStatusSnapshot`、`systemdLifecycleAction`、`systemdLogs` 以及各 `/local/*` handler。
- `portable-runtime/ui/index.html`：systemd SSH 配置、unit path 展示、后端优先级提示。
- `portable-runtime/main_test.go`：优先级与回退的回归测试。

## 8. 失败与容错行为

- Controller 直连失败**不会**立即把整个后端判死：GoWebUI 先尝试同一 Controller API 的 SSH/服务器本机端口路径；API 仍不可用时，状态场景再继续 systemd 与 Management。
- `restart` / `reload` 的 Core API 失败后继续 systemd，再到 Management；其中 reload 只有 `CanReload=yes` 才执行 systemd，否则直接进入 Management。
- `start` / `stop` 不先探测 Controller，因为它不是对应生命周期能力；直接 systemd，再到 Management。
- systemd SSH 如果主机不可达、SSH 认证失败、没有 `mihomo.service`、`sudo -n` 无权限或命令失败，会进入该操作允许的下一级回退。GoWebUI 的 LAN Profile 在 SSH target 留空时会自动推断 host；如果 SSH 用户不是当前 macOS 用户，应显式配置 `user@host`。
- Management 未配置时，Controller + systemd 已经足够完成绝大多数 Core 管理；但订阅事务和整套项目升级仍会明确提示需要 Core 服务面板。
- 所有 Secret 不写入 Profile JSON；Controller / Management Secret 保持使用 macOS Keychain。SSH 私钥只保存**路径**，不会把私钥内容复制进 App 配置。

## 9. v1.3.1 回归测试要求

本次修复新增并要求持续保留以下门禁：

- systemd SSH 参数必须使用显式端口与可选 identity，不能拼成 shell 本地命令。
- start 必须 `systemd -> Management`。
- restart 必须 `Controller -> systemd -> Management`。
- reload 必须保持 `Controller -> systemd -> Management` 的层次，但 systemd 只在 `CanReload=yes` 时实际执行。
- status 必须保持 `Controller -> systemd -> Management` 主链，并验证 Management 慢速元数据可补齐面板/XD 版本而不覆盖 Controller Core 版本。
- logs 必须 `journal -> Management`，且失败时不得丢失 journal/systemd 的错误原因。
- GoWebUI Controller/Management 网络不可达时必须测试 `direct HTTP -> SSH 原 URL -> SSH 127.0.0.1:原端口`。
- 代理切换的 mutating PUT 只有在“未建立 HTTP 连接”时才允许尝试 loopback，明确 HTTP 响应不得二次重放。
- LAN Profile 的空 SSH target 可从 Management/Controller host 推断；公共域名不得自动探测 SSH。
- unit 名固定 `mihomo.service`，action verb 为白名单。
- Profile SSH 端口必须限制在 `1...65535`。
- v1.3.1 / build 1301、arm64、macOS 14.0 基线不得因 hotfix 改变。

## 10. 参考

- Mihomo 官方 API：<https://wiki.metacubex.one/en/api/>
- Mihomo 官方 systemd service 指南：<https://wiki.metacubex.one/en/startup/service/>
- systemd `systemctl` 文档：<https://www.freedesktop.org/software/systemd/man/latest/systemctl.html>

