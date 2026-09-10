# Mihomo Core Manager v1.1.2

v1.1.2 是界面修复与紧凑化版本：保留 v1.1.1 的功能，同时恢复 v1.0.9 菜单栏样式，并优化主窗口过高的标题栏。

## 菜单栏界面修复

- 恢复 v1.0.9 的原生 SwiftUI 菜单栏标签布局。
- 恢复 `Running / Stopped / Checking` 状态文案。
- 恢复 `↓ / ↑` 文字箭头与原有双行网速对齐。
- 恢复 v1.0.9 的字号、间距与固定尺寸策略。

## 主窗口标题栏优化

- 主窗口采用 SwiftUI `hiddenTitleBar` 窗口样式，隐藏标准标题文字和标题栏底板。
- Dashboard 内容延伸到原标题栏区域，减少顶部无效高度和大块空白。
- `NSWindow` 使用透明标题栏、无标题栏分隔线和 `fullSizeContentView`。
- 保留 macOS 原生红黄绿窗口按钮，不缩放、不自绘。
- 保留原生标题栏拖拽和背景拖拽。
- 左侧品牌区仅增加紧凑安全间距，防止与窗口按钮重叠。

## 保留的 v1.1.1 功能

- 管理后端选择器及多服务器 Profile。
- 持久化 Dashboard 页面与按需加载。
- 状态缓存、菜单栏刷新与恢复逻辑。
- portable runtime / Web UI。
- 无 Apple Secrets 的 unsigned GitHub Release 流程。

版本：App v1.1.2 (build 112)，API 兼容基线 v4.0.0。
