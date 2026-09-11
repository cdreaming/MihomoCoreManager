# Mihomo Core Manager v1.2.2

v1.2.2 是 v1.2.1 的 GitHub Actions 构建热修复。v1.2.1 的状态栏显示修复本身保持不变；本次修复 Release workflow 在构建 portable arm64 安装包时缺少 Go 工具链、导致 `Go is required` 并以 exit code 1 终止的问题。

## GitHub Actions 构建修复

- 根因：v1.2.1 首次把 `scripts/build-portable-installer.sh` 加入 macOS Release job，但 `macos-15` Runner 上不能假定预装 Go；脚本启动时执行 `command -v go`，因此 Release 在正式 `.pkg/.zip` 构建之后、portable 阶段直接失败。
- Release workflow 现在在任何 portable 测试/构建之前显式执行 `actions/setup-go@v6`，并从 `portable-runtime/go.mod` 读取 Go 版本；项目无第三方 Go 依赖，因此关闭 action cache，避免不存在 `go.sum` 时产生无意义的缓存依赖。
- 新增 Go 工具链 smoke test：输出 `go version` 并运行 `CGO_ENABLED=0 go test ./...`，让工具链问题在正式发布构建前立即暴露。
- 普通 macOS CI 同步安装同一 Go 工具链并实际执行 `scripts/build-portable-installer.sh`，以后 portable Release 路径会在 main/PR 阶段提前回归，不再只到打 tag 时才发现环境缺失。
- CI artifact 同时保留 `dist/` 与 `dist-portable/`，便于检查正式 SwiftUI 与 portable 两条交付路径。

## 保留的 v1.2.1 修复

- GitHub/Xcode 正式版继续使用固定 `55×18pt` template `NSImage` 渲染状态栏双行网速，避免 `MenuBarExtra` 压缩多行 SwiftUI 内容。
- 上传在上、下载在下；数字左对齐并预留 4 个等宽字符位；单位自动切换，状态栏本体不显示方向箭头。
- v1.1.9 自定义下拉面板和 v1.2.0 portable/AppKit 状态栏实现保持不变。

请使用新 tag `v1.2.2` 发布，不要移动已存在的 `v1.2.1` tag。

App v1.2.2 (build 122)，Mihomo Core 管理面板 API 兼容基线 v4.0.0。
