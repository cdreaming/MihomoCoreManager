# Mihomo Core Manager v1.0.4

v1.0.4 继续兼容 **Mihomo Core 管理面板 v4.0.0**，重点修正窗口交互、左侧后端选择器和状态栏排版。

## 窗口交互

- 恢复标准 macOS 窗口拖动行为。
- 原生 SwiftUI 明确保持窗口 `isMovable`。
- portable AppKit/WebKit 壳新增透明标题栏拖动层；WebKit 即使占满窗口内容，也可通过顶部标题区域调用原生 `performWindowDragWithEvent:` 拖动窗口。

## Mihomo Core 后端选择器

- 左侧选择器高度提升为 54pt/px，图标、服务器名称、端点地址和展开箭头重新排版。
- 原生 SwiftUI 不再使用高度过矮的系统 Menu，下拉改为与 Dashboard 同视觉的 Popover。
- Popover/portable 下拉的每个服务器项保持 54pt/px 高度，并显示当前选择状态、服务器名称和主机/端口。
- 下拉底部保留“服务器设置…”入口。

## 状态栏排版

- `Running / Stopped / Offline` 保持独立单行显示。
- 上传/下载速度作为独立两行块放在状态右侧，并上下居中：

  `↑ Upload rate`

  `↓ Download rate`

- 运行状态不再与上传第一行混排。
- “显示运行状态 / 显示网速 / 仅显示图标”开关继续保留并持久化。

## 保留

- v1.0.3 的设置 Tab、常驻页面、异步流量图、集中状态缓存和卡顿优化。
- v1.0.2 的 Mihomo Core 管理面板 Dashboard UI、多服务器/跨机管理。
- v1.0.1 的 Core Secret `⌘V` 与显式粘贴按钮。
- GitHub Actions arm64 构建、Developer ID 签名、Apple 公证、Staple 与 `.pkg` 自动发布流程。

版本：App v1.0.4 (build 104)，API 兼容基线 v4.0.0。
