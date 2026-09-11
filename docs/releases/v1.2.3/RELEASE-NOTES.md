# Mihomo Core Manager v1.2.3

v1.2.3 基于 v1.2.2 开发，重点加入 Mihomo Core 原生代理切换能力。

## 新增

- 修复 Controller 认证：新增独立 Controller Secret（对应 `config.yaml` 的 `secret`），避免与管理面板 Core Secret 不一致时出现 HTTP 401；留空时兼容复用 Core Secret。
- 新增“代理切换”侧栏页面。
- 使用当前 Profile 的 Direct Core Controller URL + Core Secret 连接 Mihomo Core。
- 支持运行模式：规则（rule）、全局（global）、直连（direct）。
- 展示全部可见代理组、当前选择和组内详细代理。
- 详细代理显示类型、存活状态、最近延迟及 UDP / XUDP / TFO 能力。
- 支持 Selector / URLTest / Fallback 组切换目标代理。
- 支持代理名称搜索筛选。
- portable arm64 安装版同步支持相同功能，并通过本地 Go bridge 安全转发 Controller 请求。

## Controller API

- `GET /configs`
- `PATCH /configs`
- `GET /proxies`
- `PUT /proxies/{group}`

Controller 请求继续使用当前 Profile 保存的 Core Secret 作为 Bearer Token。

## 版本

- App: `1.2.3`
- Build: `123`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: `14.0`
