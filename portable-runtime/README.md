# GoWebUI arm64 preview/runtime

从 v1.3.0 起，这里不再只是“回归用 portable 实现”，而是两条正式实现之一：**Go/AppKit/Web UI（GoWebUI）**。

固定关系：

- `scripts/build-gowebui-app.sh`：唯一 GoWebUI `.app` builder。
- `scripts/build-portable-installer.sh`：ChatGPT Web/Linux 快速交付，调用同一个 App builder。
- `scripts/build-gowebui-release.sh`：GitHub macOS runner 正式 `GoWebUI.pkg`，也调用同一个 App builder。
- `scripts/build-swiftui-release.sh`：另一条独立 SwiftUI/AppKit 原生实现。

因此，开发阶段拿到的 GoWebUI portable 和 GitHub 的 GoWebUI.pkg 不再是两套 UI 源码；二者共享本目录的 Go runtime、`ui/index.html`、版本/build、Info.plist 生成逻辑和 AppIcon 资产。

## 技术结构

- `GOOS=darwin GOARCH=arm64 CGO_ENABLED=0` 生成 Apple Silicon Mach-O 主进程。
- 主进程仅监听随机 `127.0.0.1` 端口，并用每次启动随机 token 保护本地 API。
- JXA + AppKit/WebKit 提供窗口与状态栏；远端 Mihomo 请求由 Go 进程发送，因此不受 WebKit CORS 限制。
- Profile 非敏感字段写入 `~/Library/Application Support/MihomoManager/settings.json`，旧 `MihomoCoreManager/settings.json` 仅用于迁移；Secret 使用 macOS Keychain。
- 状态栏、代理切换、线路延时、Controller `/group`/`/proxies` 合并、窗口生命周期等 v1.2.x 稳定性修复继续保留。

## v1.3.5 status-menu parity

- GoWebUI 与 SwiftUI 的状态栏入口和下拉菜单头部统一使用同一份 `BrandLogo` / AppIcon 图形资源；下拉头部改为“大 LOGO 左侧跨两行 + 右侧两行状态/网速”。
- 状态栏统一采用“LOGO 靠左、运行状态点居中、实时网速块靠右”的布局，网速区域固定宽度以避免跳动。
- 关闭主窗口只隐藏/关闭主界面，状态栏菜单继续运行；从状态栏执行“退出”才终止整个应用。
- 版本统一为 v1.3.5 / build 1305。

## v1.3.2 networking / service policy

- 正式 GoWebUI 构建使用 Go 1.26.8；打包后必须验证 Mach-O `LC_UUID`，并声明 `NSLocalNetworkUsageDescription`。
- Management Secret 统一使用 `cc.kkr.MihomoManager.profile-secret`；兼容迁移 v1.3.1 错误 service，并在保存后回读校验。
- SSH 不再从 LAN URL 自动推断。只有显式填写 `systemdSSHTarget` 才启用 SSH/HTTP-over-SSH/systemd/journalctl 回退。
- 服务状态/动作/日志优先 Controller 与 Core 服务面板 API，显式 SSH 只作为最终高级回退。

## v1.3.1 networking

- 局域网目标（私网 IP、loopback/link-local、`.local` / `.lan` / `.home.arpa`、单标签主机）绕过继承的 HTTP(S) 环境代理。
- `CGO_ENABLED=0` 的 macOS runtime 对本地主机名增加系统解析器回退。
- Cloudflare Tunnel/网关临时故障会清理空闲连接并对只读请求、状态轮询和代理菜单轮询退避，减少恢复期请求风暴。

当前版本：v1.3.5，`VERSION=1.3.4`，`BUILD_NUMBER=1304`。
