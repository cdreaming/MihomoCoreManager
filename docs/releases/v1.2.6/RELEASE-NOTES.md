# Mihomo Core Manager v1.2.6

v1.2.6 以已经成功发布的 v1.2.5 功能为基线，不新增高风险业务能力，重点把 v1.2.4 / v1.2.5 发布过程中暴露出的 Xcode、源码清单、Go 并发测试与 GitHub Actions 问题沉淀成可自动执行的发布门禁。

## 发布可靠性

- CI 与正式 Release 统一执行 `scripts/simulate-release.sh --strict-macos`，避免两套发布步骤长期漂移。
- Apple Silicon `macos-15` Runner 上执行完整 Swift 语法解析、SDK 绑定的 `Models.swift` typecheck、Xcode Release build settings 校验和真实 `xcodebuild` Release 构建。
- Release 模式显式关闭 Swift batch mode，并把完整 Xcode 输出保存到 `build/xcodebuild-release.log`；失败时自动回显编译器 `error:` / `SwiftCompile` 诊断和日志尾部。
- 严格 macOS preflight 会在精确 checkout 上重建并复核 `SOURCE-SHA256SUMS.txt`；PR/main CI 则在进入模拟发布前先严格检查仓库中提交的 manifest，兼顾可复现性与正式发布容错。
- manifest 失配会列出新增、删除和 SHA-256 变化的具体文件。
- workflow_dispatch 若目标 tag 已存在但不指向当前 commit，会直接失败并要求使用新版本号，避免移动旧 tag。

## Swift / Xcode 回归保护

- `ProxySortOption` 显式遵循 `Hashable`，代理排序 Picker 独立为 `ProxySortPicker`，并把代理组详情 ViewBuilder 拆成更小的构建单元，降低 Release 模式类型推断压力。
- `Bool?` 存活状态 switch 使用 `.some(true) / .none / .some(false)` 的穷尽模式，避免 Xcode 16.x 在 Release 编译中判定 switch 不完整。
- 清理已弃用的单参数 `onChange(of:)` 调用。
- strict preflight 通过 `xcrun --sdk macosx --show-sdk-path` 获取当前 Xcode SDK，并用 `-sdk` + `-target arm64-apple-macos14.0` 做语义 typecheck，避免裸 `swiftc -typecheck` 无法加载 macOS 标准库。

## Portable / Go 回归保护

- 所有应用自身的短生命周期后台刷新统一通过 `backgroundWG + goBackground()` 跟踪，测试与进程退出可等待这些任务完成，防止后台 goroutine 与 `testing.TempDir` 清理竞争。
- `TestGroupDelayCacheDecoratesSharedProxyData` 发布模拟中连续执行 300 次；全套测试随机顺序重复执行，并增加 `go test -race` 与 `go vet`。
- 额外交叉编译 Darwin/arm64 Go test binary，并校验其为 thin Mach-O arm64。
- portable installer 构建后校验 Mach-O CPU、ZIP CRC、App bundle 结构、版本号与 SHA-256。

## 发布资产

- `MihomoCoreManager-v1.2.6-arm64.pkg`
- `MihomoCoreManager-v1.2.6-arm64.zip`
- `MihomoCoreManager-v1.2.6-arm64-portable-installer.zip`
- `release_v1.2.6_notes_zh-CN.md`
- `SHA256SUMS.txt`

## 版本

- App: `1.2.6`
- Build: `126`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: `14.0`
