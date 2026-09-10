# Mihomo Core Manager for macOS

基于 **Mihomo Core 管理面板 v4.0.0** API 开发的 Apple Silicon（arm64）macOS 管理客户端。当前 App 版本为 **v1.1.7 (build 117)**；`v4.0.0` 是服务端兼容基线，不是 App 版本。

## v1.1.7

v1.1.7 优化异步操作按钮的完整执行反馈：

- “开始项目升级”不再在远端仅返回“已启动”后立即恢复；持续读取升级日志的 `running` 状态，确认任务结束后才恢复初始按钮。
- 升级 Core 管理面板导致远端短暂重启/断连时保持“项目升级中…”状态并继续检测，避免误判失败或提前结束动画。
- 原生 SwiftUI 为当前执行按钮显示 `ProgressView`；鼠标停留在执行中按钮时切换为旋转 busy cursor，开启“减少动态效果”时自动使用静态指针。其它操作保持禁用，完成/失败后统一由 `defer` 恢复。
- portable Web UI 为执行中按钮增加 spinner、`aria-busy` 和全局 `cursor: progress` 忙碌指针反馈。
- 按压效果增强：原生按钮按下缩放到 `0.955` 并加入位移/阴影反馈；Web 按钮缩放到 `0.945` 并增加高亮闪层与内阴影。
- 保留 `prefers-reduced-motion` / macOS Reduce Motion 兼容。

## v1.1.6

v1.1.6 再次修复按钮交互，直接恢复 v1.0.9 的实现：

- `DashboardActionButtonStyle` 与 v1.0.9 源码实现一致。
- 删除 v1.1.5 新增的 `DashboardPressButtonStyle`。
- 删除显式 `0.08s easeOut` 和额外 disabled opacity 动画。
- 侧栏、管理后端、Popover、文本链接、通知关闭按钮恢复 v1.0.9 的 `.plain` 行为。
- 主操作按钮保留 v1.0.9 的按下背景反馈与 `0.985` 缩放。
- v1.1.5 的设置页纵向结构、双列“App 与状态栏”和统一页面 UI 全部保留。

## v1.1.5

- 全量统一按钮按压反馈，参考 v1.0.9 的背景变化与 `0.985` 缩放，并补充稳定的 0.08 秒回弹。
- 移除会复制 Button 子树的 `ViewThatFits`。
- 设置页纵向排列；“App 与状态栏”改为双列分组。
- 概览和 Core 成对卡片统一高度；日志页统一页面结构。

## v1.1.4

这是 v1.1.3 统一布局版的构建修复版本，正式版本升级为 **v1.1.4 (build 114)**。

- 修复 `OverviewView.swift` 中 SwiftUI `frame` 参数组合导致的 Xcode 16.4 编译失败。
- 将固定宽度与最小高度拆分为两个合法的 `frame` 修饰器，保持“实时流量 / 快速控制”布局设计不变。
- 增加源码校验规则，提前拦截固定 `width/height` 与 `min/max/ideal` 尺寸混用的非法 `frame` 调用。
- 保留 v1.1.3 的统一页面布局、紧凑标题栏和 v1.0.9 菜单栏样式。

## v1.1.3

本版本基于已完成界面统一修复的 v1.1.2 源码发布，版本升级为 **v1.1.3 (build 113)**。

- 保留 v1.1.2 的紧凑标题栏优化。
- 保留“概览 / Core 控制 / 订阅管理 / 设置”等页面的统一布局修复。
- 保留 v1.0.9 风格的原生菜单栏标签界面。
- 不改变 Mihomo Core API、订阅处理、升级流程和 portable runtime 功能逻辑。

## v1.1.2

这一版在保留 v1.1.1 功能的基础上，修复界面并压缩主窗口顶部占用：

- **菜单栏恢复 v1.0.9 风格**：恢复原有布局、字号、间距、`Running / Stopped / Checking` 文案与 `↓ / ↑` 双行网速显示。
- **紧凑标题栏**：主窗口使用隐藏标题栏底板的原生窗口样式，让 Dashboard 延伸到顶部，减少空白和无效高度。
- **保留系统窗口按钮**：红黄绿按钮仍使用 macOS 原生控件，不做缩放或自绘。
- **避免顶部重叠**：左侧品牌区为窗口按钮保留紧凑安全区，不重新制造厚标题栏。
- **功能保持 v1.1.1**：管理后端选择器、窗口拖拽、性能优化、portable runtime 和 unsigned Release 流程全部保留。

## v1.1.1

这一版集中修复原生状态栏显示问题：

- **更紧凑的状态栏宽度**：收紧 `MenuBarExtra` 标签横向间距，减少左右空白占用。
- **更好的垂直居中**：统一状态栏标签高度，修复图标、状态文本和双行网速在菜单栏内上下不居中的问题。
- **更稳定的双行网速排版**：上传/下载箭头改用 SF Symbols，并优化两行间距与对齐。
- **更短的状态文案**：显示 `On / Off / Wait`，减少状态栏横向长度。
- 继续保留 v1.1.0 的无需 Apple Developer Secrets 的 Release 自动构建流程。

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

正式 tag `v1.1.7` 成功后生成：

```text
MihomoCoreManager-v1.1.7-arm64.pkg
MihomoCoreManager-v1.1.7-arm64.zip
release_v1.1.7_notes_zh-CN.md
SHA256SUMS.txt
```

v1.1.0 默认 Release **不需要 Apple Developer Repository Secrets**。默认产物没有 Developer ID / Apple Notary 身份；若以后需要正式签名与公证，可继续使用保留的 `scripts/build-release.sh --signed` 路径并重新接入 Apple 凭据。

## 当前非 macOS 构建环境的交付说明

`portable-runtime/` 可在 Linux 上交叉编译为 `darwin/arm64` Mach-O，并在 macOS 上通过系统 AppKit/WebKit + JXA 提供主窗口与状态栏菜单，用于即时安装/测试。GitHub Release 仍以 Xcode/SwiftUI 目标为准；v1.1.0 默认走无需 Apple 凭据的未签名发布路径。
