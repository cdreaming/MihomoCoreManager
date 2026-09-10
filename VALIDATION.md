# Validation Report — v1.2.0

- App `1.2.0` / Xcode build `120` / portable build `120`。
- v1.1.9 自定义状态栏下拉面板保持不变。
- 原生状态栏上传在上、下载在下；双行速度块靠下、左对齐，数字区域固定预留 4 个等宽字符位，状态栏本体不显示箭头。
- portable JXA 状态栏改用将点击转交给状态栏按钮的 AppKit overlay + 独立 `NSTextField` 行，绕过 `NSStatusBarButton` 默认单行 title 对换行的裁切。
- portable 速度数字列/单位列独立布局并左对齐，单位按 `B/s / KB/s / MB/s / GB/s / TB/s` 自动变化。
- 继续禁止 portable 启动路径使用 `NSButtonCell` 多行属性、`attributedTitle` / baseline offset 和 `CATextLayer`。
- Source validator、portable Go 回归测试、Swift parse 与源码 SHA manifest 均作为 v1.2.0 发布门禁。
