# Mihomo Core Manager v1.2.0

v1.2.0 以 v1.1.9 为稳定基线，本版只修状态栏本体的实时网速显示；v1.1.9 已确认效果的状态栏下拉面板保持不变。

## 状态栏网速

- 修复 portable 安装版在 `NSStatusBarButton` 默认单行 cell 下使用换行 title，导致状态栏本体只剩图标/箭头或速度文字被裁切的问题。
- 改为状态栏按钮内独立 AppKit overlay：上传和下载分别由原生 `NSTextField` 渲染，overlay 与子标签会把点击转交给状态栏按钮，因此不会缩小状态栏点击范围。
- 上传显示在上半行、下载显示在下半行，并把整个速度块向菜单栏底部对齐。
- 状态栏本体只显示速度数字和自动变化单位，不显示上传/下载箭头。
- 数字使用等宽字体，左对齐并固定预留 4 个字符位；单位单独成列，在 B/s、KB/s、MB/s、GB/s、TB/s 之间自动变化。
- 原生 SwiftUI 状态栏同步采用同样的布局规则。

## 稳定性

- 不恢复 `NSButtonCell.wraps / usesSingleLineMode` 修改。
- 不使用 `attributedTitle` baseline offset。
- 不使用 `CATextLayer`。
- overlay 创建失败时仍保留安全单行降级路径，不让状态栏渲染问题带崩整个 portable App。

App v1.2.0 (build 120)，Mihomo Core 管理面板 API 兼容基线 v4.0.0。
