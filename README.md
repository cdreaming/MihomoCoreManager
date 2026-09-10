# Mihomo Core Manager for macOS

基于 **Mihomo Core 管理面板 v4.0.0** API 开发的 Apple Silicon（arm64）macOS 管理客户端。当前 App 版本为 **v1.1.0 (build 110)**；`v4.0.0` 是服务端兼容基线，不是 App 版本。

## v1.1.0

这一版主要修复 GitHub Actions 自动 Release 在没有 Apple Developer 凭据时直接失败的问题：

- **Release 默认无需 Apple Secrets**：移除 Developer ID / Notary Secrets 强制校验和证书导入步骤。
- **自动构建未签名 Release**：GitHub Actions 默认使用 `scripts/build-release.sh --unsigned`，继续生成 arm64 `.zip`、`.pkg`、Release Notes 和 SHA-256 清单。
- **保留自动发布**：支持 tag `v1.1.0` 和手工 `workflow_dispatch`，并自动创建/更新 GitHub Release、上传资产、在线回读验证 SHA-256。
- **保留正式签名能力**：`scripts/build-release.sh --signed` 路径未删除，以后有 Apple Developer 证书时仍可重新启用签名与公证。
- **安装提示**：默认产物没有 Developer ID / Apple Notary 身份，其它 Mac 首次安装/启动时可能出现 Gatekeeper 提示。
- 保留 v1.0.9 的状态栏组合显示、订阅热重载超时安全恢复及此前全部功能。

## v1.0.9

这一版集中修复状态栏组合显示与订阅“保存并应用”超时问题：

- **图标 / 网速 / 运行状态可同时显示**：三项改为独立开关；状态栏仍使用紧凑双行网速（下载在上、上传在下），图标与运行状态可以同时保留。
- **升级兼容**：旧版设置没有 `showIcon` 字段时自动按“显示图标”迁移，避免升级后图标意外消失；若三项被全部关闭，会自动保留图标以确保菜单仍可点击。
- **订阅热重载超时自动恢复**：Mihomo Core 管理面板 v4.0.0 会把保存、renderer 校验和热重载放在一个事务里，热重载超时会回滚配置。v1.0.9 仅在确认是“热重载超时且已回滚”时自动切换为一次安全重启流程：停止 Core → 再次保存并校验 → 启动 Core。
- **避免误重启**：URL 非法、renderer 失败、配置校验失败等其它错误不会触发安全重启，仍按原错误返回。
- 保留 v1.0.8 的等宽“管理后端”下拉、v1.0.7 的菜单栏崩溃保护/Recovery Shell、Core Secret 粘贴、窗口拖动与集中状态缓存。

## 功能范围

1. **Apple Silicon arm64 原生应用**：Xcode 工程固定 `ARCHS=arm64`，最低 macOS 14.0。
2. **跨域 / 跨机管理**：正式 SwiftUI App 使用原生 `URLSession`，不受浏览器 CORS 限制；支持多服务器 Profile、域名、内网 IP 与 VPN 地址。
3. **配置设置**：每台服务器可设置 Management URL、Core Secret、Direct Core Controller URL、远端 `config.yaml` 路径、MetaCubeXD URL、HTTP 兼容和升级保留策略。
4. **状态栏管理**：图标、运行状态、实时网速三项可独立开关并同时显示，菜单覆盖日常管理动作。
5. **自动发布**：GitHub Actions 在 macOS arm64 Runner 构建；v1.1.0 默认无需 Apple Developer Secrets，自动生成未签名 `.pkg` / ad-hoc 签名 App ZIP 并发布到 GitHub Release。

## v4.0.0 API 兼容

| 功能 | API |
| --- | --- |
| 状态 / 流量 / 版本 | `GET /api/status` |
| Core 启停 / 重启 / 热重载 | `POST /api/action` |
| 订阅读取 / 保存应用 | `GET/POST /api/subscriptions` |
| 运行日志 | `GET /api/logs?lines=N` |
| 项目更新检查 | `GET /api/project-update/check` |
| 项目更新执行 | `POST /api/project-update/apply` |
| 更新日志 | `GET /api/project-update/log` |

认证使用 `Authorization: Bearer <Core Secret>`。Secret 不写入 Profile 文件，正式 App 使用 macOS Keychain；portable runtime 使用 `/usr/bin/security` 访问同一 Keychain service。

## 本地构建

要求：Apple Silicon Mac + Xcode（macOS 14 SDK 或更高）。

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
xcodebuild \
  -project MihomoCoreManager.xcodeproj \
  -scheme MihomoCoreManager \
  -configuration Debug \
  -destination 'platform=macOS' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  build
```

## Release

正式 tag `v1.1.0` 成功后生成：

```text
MihomoCoreManager-v1.1.0-arm64.pkg
MihomoCoreManager-v1.1.0-arm64.zip
release_v1.1.0_notes_zh-CN.md
SHA256SUMS.txt
```

v1.1.0 默认 Release **不需要 Apple Developer Repository Secrets**。默认产物没有 Developer ID / Apple Notary 身份；若以后需要正式签名与公证，可继续使用保留的 `scripts/build-release.sh --signed` 路径并重新接入 Apple 凭据。

## 当前非 macOS 构建环境的交付说明

`portable-runtime/` 可在 Linux 上交叉编译为 `darwin/arm64` Mach-O，并在 macOS 上通过系统 AppKit/WebKit + JXA 提供主窗口与状态栏菜单，用于即时安装/测试。GitHub Release 仍以 Xcode/SwiftUI 目标为准；v1.1.0 默认走无需 Apple 凭据的未签名发布路径。
