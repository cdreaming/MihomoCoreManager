# Validation Report — v1.2.2

- App `1.2.2` / Xcode build `122` / portable build `122`。
- 已复现并定位 v1.2.1 GitHub Release 失败根因：Release job 调用 `scripts/build-portable-installer.sh` 前没有配置 Go，脚本在 `command -v go` 处以 `Go is required` 退出。
- `.github/workflows/release.yml` 现在显式使用 `actions/setup-go@v6`，版本由 `portable-runtime/go.mod` 提供；在 Release 构建前运行 `CGO_ENABLED=0 go test ./...`。
- `.github/workflows/ci.yml` 同步配置 Go，并实际运行 portable installer 构建脚本，确保同类环境缺失能在 PR/main CI 阶段发现。
- v1.2.1 正式 Xcode/SwiftUI 状态栏 template image 修复保持不变。
- Source validator、portable Go 回归测试、Swift parse、workflow YAML 解析与源码 SHA manifest 作为 v1.2.2 发布门禁。
