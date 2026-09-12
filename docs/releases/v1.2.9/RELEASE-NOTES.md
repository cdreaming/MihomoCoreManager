# Mihomo Core Manager v1.2.9

v1.2.9 基于 v1.2.8 稳定版本，修复 GitHub/Xcode `.pkg` 安装版状态栏下拉窗口被固定为滚动框的问题。

## 版本

- App: `1.2.9`
- Build: `129`
- Xcode `MARKETING_VERSION`: `1.2.9`
- Xcode `CURRENT_PROJECT_VERSION`: `129`
- portable runtime: `1.2.9 / 129`

## 修复

- 移除原生 `MenuBarView` 外层始终启用的固定 `ScrollView + maxHeight: 720` 布局。
- 菜单内容能够放入当前屏幕时，窗口按内容自然高度完整展开，不再出现无意义的固定边框和拖动条。
- 菜单内容高度超过当前显示器可用区域时，自动切换为纵向滚动，可上下滑动访问全部菜单项。
- 菜单最大高度从状态栏窗口实际所在 `NSScreen.visibleFrame` 动态计算；切换显示器或屏幕参数发生变化时自动更新。
- 发布校验新增 v1.2.9 状态栏自适应高度门禁，禁止回退到固定 720pt 滚动框。
- 保留 v1.2.8 的主窗口生命周期、状态栏 shell 单次自动恢复以及恢复模式窗口拖动修复。

## GitHub Release

在 Apple Silicon `macos-15` GitHub Actions runner 上执行 `scripts/simulate-release.sh`，通过 Xcode Release 构建后生成：

- `MihomoCoreManager-v1.2.9-arm64.pkg`
- `MihomoCoreManager-v1.2.9-arm64.zip`
- `MihomoCoreManager-v1.2.9-arm64-portable-installer.zip`

`.pkg` 必须来自 Xcode 原生目标构建，不能用 portable runtime 替代。
