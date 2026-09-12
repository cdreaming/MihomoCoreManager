# Mihomo Core Manager v1.2.10

v1.2.10 基于 v1.2.9，重点修复 GitHub Actions / Xcode 生成的原生 `.pkg` 在状态栏显示、代理组当前线路和深色界面层级上的差异。

## 版本

- App: `1.2.10`
- Build: `1210`
- Xcode `MARKETING_VERSION`: `1.2.10`
- Xcode `CURRENT_PROJECT_VERSION`: `1210`
- portable runtime: `1.2.10 / 1210`

## 修复与优化

- **状态栏实时信息**：不再用多个 SwiftUI 子视图拼接 `MenuBarExtra` 标签。原生版会把图标、运行状态和上传/下载双行网速渲染成一张可变宽的 AppKit template image，解决 Release `.pkg` 只显示首个图标的问题。
- **状态栏开关**：图标、状态、网速开关直接参与整张状态栏图像渲染，切换后强制刷新 label identity，避免视觉上像“开关失效”。
- **下拉菜单背景**：新增 `DashboardPalette.menuBackground`，比原近纯黑背景更柔和，同时保留卡片、分隔线和按钮层级。
- **滚动条**：内容超过当前屏幕时保留纵向滚动能力，但显式隐藏系统滚动指示器；内容未超屏时仍按自然高度全部展开。
- **代理组当前线路**：当前 `now` 选择改为组名同一行的可见标签，避免两行 `Menu` label 在 Release 构建中被压缩；每次呈现状态栏菜单会重新刷新代理快照。
- **主窗口右侧背景**：右侧详情区改用深灰蓝渐变背景，减少大面积近纯黑，同时保持现有 Dashboard 卡片对比度。

## 保留修复

- 保留 v1.2.9 的状态栏菜单自适应屏幕高度。
- 保留 v1.2.8 的主窗口关闭/重开可拖动、状态栏 shell 自动恢复与恢复模式拖动修复。
- 保留 v1.2.7 以来的发布门禁、Cloudflare 容错、代理测速与切换逻辑。

## GitHub Release 资产

- `MihomoCoreManager-v1.2.10-arm64.pkg`
- `MihomoCoreManager-v1.2.10-arm64.zip`
- `MihomoCoreManager-v1.2.10-arm64-portable-installer.zip`
- `release_v1.2.10_notes_zh-CN.md`
- `SHA256SUMS.txt`
