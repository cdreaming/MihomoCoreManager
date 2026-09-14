# MihomoManager v1.3.6

v1.3.6 以 v1.3.5 为基线，集中优化 macOS 状态栏实时网速的共同单位、对齐和占位宽度，并同步修改 SwiftUI / GoWebUI 两套实现。

## 版本

- App: `1.3.6`
- Build: `1306`
- Architecture: `arm64`
- Minimum macOS: `14.0`

## 状态栏网速

- 上传/下载强制使用同一单位，由两者中较大的实时速度决定共同单位。
- 共同数字列右对齐，单位列同起点；单位右缘贴状态项右边界，LOGO 贴左边界。
- 状态栏速度本体不增加 `↑` / `↓` 标识。
- 元素间距从 6pt 缩为 2pt。
- 删除固定 53pt 网速占位，改为按当前两行数字与共同单位的实际文字宽度动态缩小。
- 两行网速整体略向下调整。
- SwiftUI 使用 AppKit 字体测宽；GoWebUI/AppKit 使用 `NSTextField.sizeToFit`，两套实现保持相同布局规则。

## 服务设置保存位置

- GoWebUI 非敏感 Profile / 菜单偏好：`~/Library/Application Support/MihomoManager/settings.json`。
- SwiftUI 非敏感 Profile：`~/Library/Application Support/MihomoManager/profiles.json`。
- SwiftUI 当前 Profile、状态栏显示偏好等使用 `UserDefaults`。
- Management Secret / Controller Secret 使用 macOS Keychain，不写入上述 JSON。
- 旧 `~/Library/Application Support/MihomoCoreManager/` 数据仍保留迁移兼容。
