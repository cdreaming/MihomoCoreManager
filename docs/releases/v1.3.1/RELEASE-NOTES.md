# Mihomo Core Manager v1.3.1

> **同版本 hotfix / build 1301 不变：** 修正“后端管理”标签，恢复 v1.3.0 设置项兼容能力，并将 Core 重启优先切换到 Mihomo `POST /restart`；其它导航标签不变。

v1.3.1 以 v1.3.0 为基线，主要修复界面顶部对齐、局域网后端连接与 Cloudflare Tunnel 稳定性，并替换全套应用/界面图标。

## 版本

- App: `1.3.1`
- Build: `1301`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: 14.0
- GoWebUI build toolchain: Go `1.23.2`

## 界面与图标

- SwiftUI 与 GoWebUI 右侧内容顶部统一为 38pt/px，不再高于左侧品牌区；底部留白同步整理。
- “设置”Tab 和页面标题统一改为“服务设置”。
- 使用 `branding/MihomoCoreManager-2.png` 作为上传原图来源，生成共享 16–1024px AppIcon 和 GoWebUI 界面图标。
- SwiftUI 侧栏/概览及 GoWebUI 侧栏/概览均显示同一应用图标。

## GoWebUI 局域网连接

- 显式局域网目标绕过进程继承的 `HTTP_PROXY` / `HTTPS_PROXY`，避免私网请求被错误发往外部代理。
- 覆盖 private/loopback/link-local IP、`.local`、`.lan`、`.home.arpa` 与单标签局域网主机名。
- 因正式 GoWebUI 继续采用 `CGO_ENABLED=0`，macOS 对局域网主机名增加 `dscacheutil` 系统解析回退，改善 Bonjour/mDNS 场景。

## Cloudflare Tunnel 稳定性

- GoWebUI 安全读请求在瞬时 502/503/504/52x/530 后采用更温和的短重试，并丢弃可能失效的空闲 HTTP/2/keep-alive 连接。
- 状态轮询连续失败时从 1.2 秒逐步退避，最长 30 秒；代理菜单成功轮询降为 10 秒，失败最长退避到 90 秒，并错开启动时间。
- SwiftUI 状态轮询连续失败时指数退避，最多 30 秒；管理 API 与 Controller 统一识别 Cloudflare 530/Error 1033。
- 仍保留最近一次成功的代理数据，短时 Tunnel 抖动不会立即清空代理页/状态栏。

## 发布资产

GitHub Release 继续生成两个明确区分的安装包：

- `MihomoCoreManager-v1.3.1-GoWebUI-arm64.pkg`
- `MihomoCoreManager-v1.3.1-SwiftUI-arm64.pkg`

GoWebUI portable 与 GoWebUI.pkg 继续共用 `scripts/build-gowebui-app.sh` 和 `GoWebUI-RELEASE-LOCK.json`。
