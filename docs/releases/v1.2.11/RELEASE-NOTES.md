# Mihomo Core Manager v1.2.11

v1.2.11 基于 v1.2.10，继续修复 GitHub Actions / Xcode 原生 `.pkg` 与已验证安装版本之间的状态栏显示差异。

## 版本

- App: `1.2.11`
- Build: `1211`
- Xcode `MARKETING_VERSION`: `1.2.11`
- Xcode `CURRENT_PROJECT_VERSION`: `1211`
- portable runtime: `1.2.11 / 1211`

## 修复

- **菜单背景颜色**：按提供的 macOS 网络面板参考图取中性深灰 `#1A1A1D` 作为状态栏下拉菜单底色；菜单卡片使用 `#1C1C21` / `#201F23`，不再沿用偏蓝的 Dashboard 深色。原生 MenuBarExtra 对应 `NSWindow.backgroundColor` 也同步设为 `#1A1A1D`。
- **彻底隐藏滚动条**：当菜单内容超过屏幕时继续使用纵向 ScrollView，但通过 AppKit 获取底层 `NSScrollView` 并设置 `hasVerticalScroller=false` / `verticalScroller.isHidden=true`。鼠标滚轮、触控板和键盘滚动保持可用。
- **代理组当前线路**：代理组 label 使用单一 `组名 · 当前线路` 文本；原生状态栏窗口每次展示都会刷新 Controller。除 `/proxies` 外，本版还并行读取 `/group` 并优先合并其中的动态 `now`，解决部分 Controller / GitHub Release 组合下“有代理组但没有当前线路”的情况。首次后台加载冲突时会等待后再刷新。
- **主窗口版本信息**：左上版本区不再显示远端管理面板 `v4.0.0`，改为 `程序版本` 并读取当前 App bundle 的 `CFBundleShortVersionString`；portable 面板也同步显示应用自身版本，避免两条发布路径再次产生差异。

## 保留

- 保留 v1.2.10 的单一 AppKit 状态栏图像（图标 / 状态 / 双行网速）。
- 保留 v1.2.9 的菜单自然高度/超屏滚动策略。
- 保留 v1.2.8 的主窗口关闭后重开可拖动与状态栏恢复稳定性修复。

## GitHub Release 资产

- `MihomoCoreManager-v1.2.11-arm64.pkg`
- `MihomoCoreManager-v1.2.11-arm64.zip`
- `MihomoCoreManager-v1.2.11-arm64-portable-installer.zip`
- `release_v1.2.11_notes_zh-CN.md`
- `SHA256SUMS.txt`
