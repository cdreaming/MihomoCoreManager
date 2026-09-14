# QA — MihomoManager v1.3.6

## 版本 / 构建

- [ ] `VERSION=1.3.6`，`BUILD_NUMBER=1306`。
- [ ] SwiftUI / GoWebUI 均为 arm64，最低 macOS 14.0。

## 状态栏共同单位

- [ ] 上传、下载显示相同单位，并由两者较大速度决定单位。
- [ ] 跨过单位阈值时上下两行同步切换，不出现一行 KB/s、一行 MB/s。
- [ ] 状态栏速度正文不包含 `↑` / `↓`。
- [ ] 数字列右对齐；上下两行单位从同一 x 坐标开始。
- [ ] 单位右缘贴状态项右边界；LOGO 贴左边界。
- [ ] 元素间距为 2pt，不保留 v1.3.5 的 6pt 间距。
- [ ] 网速区域按内容实际宽度变化，不保留固定 53pt 占位。
- [ ] 两行网速相对 v1.3.5 略向下。
- [ ] SwiftUI 与 GoWebUI 行为一致。

## 设置持久化

- [ ] GoWebUI 保存后 `~/Library/Application Support/MihomoManager/settings.json` 更新。
- [ ] SwiftUI 保存后 `~/Library/Application Support/MihomoManager/profiles.json` 更新。
- [ ] Secret 不出现在 JSON 中，Keychain 读写正常。

## 回归

- [ ] 关闭主窗口后状态栏继续常驻。
- [ ] 状态栏菜单“退出 MihomoManager”可完整退出。
- [ ] `go test ./...` 通过。
- [ ] `python3 scripts/validate-source.py` 通过。
