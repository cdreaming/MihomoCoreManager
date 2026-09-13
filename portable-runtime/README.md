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
- Profile 非敏感字段写入 `~/Library/Application Support/MihomoCoreManager/settings.json`；Secret 使用 macOS Keychain。
- 状态栏、代理切换、线路延时、Controller `/group`/`/proxies` 合并、窗口生命周期等 v1.2.x 稳定性修复继续保留。

## v1.3.1 networking

- 局域网目标（私网 IP、loopback/link-local、`.local` / `.lan` / `.home.arpa`、单标签主机）绕过继承的 HTTP(S) 环境代理。
- `CGO_ENABLED=0` 的 macOS runtime 对本地主机名增加系统解析器回退。
- Cloudflare Tunnel/网关临时故障会清理空闲连接并对只读请求、状态轮询和代理菜单轮询退避，减少恢复期请求风暴。

v1.3.1：`VERSION=1.3.1`，`BUILD_NUMBER=1301`。
