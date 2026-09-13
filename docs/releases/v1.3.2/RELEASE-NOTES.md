# MihomoManager v1.3.2

v1.3.2 以 v1.3.1 为基线，重点修复 GoWebUI 在 macOS 15+ App Bundle 中访问局域网 Controller / Core 服务面板 / MetaCubeXD 时出现 `No route to host`，以及 Secret Keychain service 不一致和 SSH 被错误当成主连接方式的问题。

## 版本

- App: `1.3.2`
- Build: `1302`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: 14.0
- GoWebUI release toolchain: Go `1.26.8`

## 关键修复

- GoWebUI 发布工具链从 Go 1.23.2 升级到 Go 1.26.8，并移除 `-buildid=`。构建后强制验证 Mach-O `LC_UUID`；缺失 UUID 的安装包不能进入正式发布。
- GoWebUI 与 SwiftUI 都声明 `NSLocalNetworkUsageDescription`，明确请求访问用户配置的局域网 Mihomo Controller、Core 服务面板和 MetaCubeXD。
- Management Secret 的 Keychain service 统一为 `cc.kkr.MihomoManager.profile-secret`。兼容迁移 v1.3.1 GoWebUI 错误使用的 `cc.kkr.MihomoManager`，以及旧版 `cc.kkr.MihomoCoreManager*` service。
- Secret 写入后立即回读验证；写入失败或回读不一致不再显示“保存成功”。Controller Secret 同样执行回读验证。
- 不再根据 Management / Controller 的局域网 URL 自动推断 SSH 主机。只有用户显式填写 SSH 目标后才启用 SSH。
- 服务状态、启动、停止、重启、重载和日志统一采用 API 优先：Controller 能完成的操作优先 Controller；Core 停止时优先独立 Core 服务面板 API；显式 SSH/systemd 仅作为最后回退。
- GoWebUI 右下角状态不再显示容易误解的 `GoWebUI · Remote`。初始显示 `GoWebUI · 本机界面`，成功连接后显示实际后端 manager，失败则显示“后端未连接 · 检查设置”。

## 数据位置

GoWebUI 的普通设置保存在 `~/Library/Application Support/MihomoManager/settings.json`；运行时快照位于同目录的 `Runtime/`。Secret 不写入 JSON，而存储在 macOS Keychain。旧的 `~/Library/Application Support/MihomoCoreManager/settings.json` 仍保留迁移兼容。

## 服务管理策略

`mihomo.service` 的 SSH 管理由“推荐路径”调整为“高级回退”。对 v4 Core 服务面板而言，Management API 更适合作为独立服务控制面：它不依赖 Mihomo Controller 本身在线，并避免额外配置 SSH key、sudo 与远端 shell。SSH 仅用于没有可用面板 API、或用户明确希望直接管理 systemd/journalctl 的部署。

## 发布门禁

- GoWebUI 正式构建必须使用 Go 1.26.8。
- `scripts/verify-macho-uuid.py` 必须确认 arm64 Mach-O 中存在非零 `LC_UUID`。
- CI/Release 同时执行 Go 测试、Swift 解析、源码一致性检查和双实现发布模拟。
- recovery 模式允许旧 Go 交叉构建后插入并验证确定性 LC_UUID，但只用于离线恢复/测试，不作为正式 GitHub Release 工具链。
