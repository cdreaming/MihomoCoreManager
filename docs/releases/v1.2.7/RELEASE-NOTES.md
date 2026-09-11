# Mihomo Core Manager v1.2.7

v1.2.7 以 `MihomoCoreManager-v1.2.5-release-ready-source-4` 为功能基线，并重新套用已经成功发布的 **v1.2.5 fixed5 发布工程基线**。本次保留 source-4 的界面、状态缓存和代理菜单优化，同时恢复 v1.2.4 / v1.2.5 已验证过的 Xcode、manifest、Go 并发与发布模拟硬门禁。

## 版本

- App: `1.2.7`
- Build: `127`
- Xcode `MARKETING_VERSION`: `1.2.7`
- Xcode `CURRENT_PROJECT_VERSION`: `127`
- portable runtime: `1.2.7 / 127`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: `14.0`

## 发布链路修复

- CI 与 Release 重新统一调用 `scripts/simulate-release.sh`，不再维护两套容易漂移的局部检查流程。
- 恢复 `scripts/release-preflight.py`：strict macOS 模式基于精确 checkout 自行重建并复核 `SOURCE-SHA256SUMS.txt`。
- 恢复 Xcode SDK-bound semantic typecheck：`xcrun --sdk macosx swiftc` + 当前 macOS SDK + `arm64-apple-macos14.0`。
- 恢复 Release `SWIFT_ENABLE_BATCH_MODE=NO`、完整 `build/xcodebuild-release.log` 和失败时 Swift/Xcode `error:` 回显。
- 恢复 v1.2.4 Xcode 16.4 兼容写法：显式 Optional switch、独立 `ProxySortPicker`、拆分大型 SwiftUI result builder、显式 `Hashable`、具体 history 中间类型和 macOS 14 双参数 `onChange`。
- 恢复 portable 后台任务生命周期管理：异步缓存/状态刷新通过 `backgroundWG + goBackground()` 跟踪，TempDir 测试清理前等待后台任务完成。
- 修复测试服务器 goroutine 中调用 `t.Fatalf` 的隐患，避免 `FailNow` 从非测试 goroutine 触发。
- 发布模拟继续执行目标竞态重复测试、全套随机顺序测试、race、vet、Darwin/arm64 test binary 交叉编译、portable ZIP CRC/版本/Mach-O 校验；在 Apple Silicon macOS 上继续真实 Xcode Release build、arm64 架构和 SHA-256 回放。

## 功能基线保留

- 保留 source-4 的状态缓存平滑、HTTP keep-alive、短超时策略和安全 TLS 行为。
- 保留状态栏代理菜单结构感知增量刷新、线路切换后即时后缀更新与延迟权威校准。
- 保留 Cloudflare 530 / Error 1033 临时故障回退和最近成功代理快照。
- 保留 256pt 左侧导航 + 右侧内容、无独立视觉标题栏的主窗口布局。
- 保留当前代理排序、当前组测速、provider-only 节点和嵌套组延时解析。
