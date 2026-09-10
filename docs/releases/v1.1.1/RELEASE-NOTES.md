# Mihomo Core Manager v1.1.1

v1.1.1 主要修复原生 SwiftUI 状态栏标签过宽、左右留白偏多，以及双行网速在菜单栏内没有良好垂直居中的问题。

## 状态栏显示修复

- 收紧 `MenuBarExtra` 标签的横向间距，减少左右无效留白。
- 为整个状态栏标签设置紧凑固定高度，确保内容在菜单栏中垂直居中。
- 双行实时网速改用更稳定的 SF Symbols 上/下箭头布局，减小字体抖动与视觉偏移。
- 运行状态文本改为更紧凑的 `On / Off / Wait`，进一步减少宽度占用。
- 保留图标、运行状态、网速三项独立显示控制，以及“仅显示图标”模式。

## 继续保留

- v1.1.0 引入的 GitHub Release 默认 `--unsigned` 自动构建流程，继续无需 Apple Developer / Notary Secrets。
- Release 仍生成 arm64 `.zip`、`.pkg`、中文发布说明与 `SHA256SUMS.txt`。
- 保留订阅“保存并应用”的热重载超时安全回退、Recovery Shell、`Runtime/menubar.log`、多服务器与集中状态缓存。

版本：App v1.1.1 (build 111)，API 兼容基线 v4.0.0。
