# Validation Report — v1.2.1

- App `1.2.1` / Xcode build `121` / portable build `121`。
- 已确认 v1.2.0 portable/AppKit 状态栏路径正常，本次只修 GitHub Actions 正式 Xcode/SwiftUI target 的状态栏本体。
- 正式 `MenuBarExtra` 不再直接承载双行 SwiftUI `VStack`；上传/下载速率先绘制为一个固定 `55×18pt` template `NSImage`，从而避免 macOS 状态栏把两行压缩成一行。
- 上传在上、下载在下；速度块靠下、左对齐，数字区域固定预留 4 个等宽字符位，单位按 `B/s / KB/s / MB/s / GB/s / TB/s` 自动变化，状态栏本体不显示箭头。
- v1.1.9 自定义状态栏下拉面板保持不变。
- GitHub Release 同时产出正式 SwiftUI `.pkg/.zip` 与 portable arm64 安装包，便于做显示一致性回归。
- Source validator、portable Go 回归测试、Swift parse 与源码 SHA manifest 均作为 v1.2.1 发布门禁。
