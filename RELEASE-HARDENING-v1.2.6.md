# v1.2.6 发布经验与策略沉淀

本文件把 v1.2.4 与 v1.2.5 的实际发布故障固化为规则，目标不是“失败后再补一个点”，而是在同一条发布模拟链路中一次性覆盖源码、Swift/Xcode、Go、产物与 GitHub Release 回读。

## 1. 编译器问题必须在真实 Xcode gate 中暴露

Linux Swift 解析只能证明语法结构可解析，不能替代 AppKit/SwiftUI 的 macOS SDK 编译。v1.2.6 保留跨平台 parse，同时在 `macos-15` Apple Silicon Runner 上执行 SDK-bound typecheck 和真实 Release `xcodebuild`。

Release 编译固定：arm64、macOS 14.0、Swift 5、`SWIFT_ENABLE_BATCH_MODE=NO`。已知高风险 SwiftUI 代码使用更小的 ViewBuilder，Optional Bool switch 使用显式 `.some/.none` 模式。

## 2. 生成型 manifest 不能挡在真实编译之前

PR/main CI 必须检查提交的 `SOURCE-SHA256SUMS.txt` 是否最新；正式 Release 在精确 tag/commit checkout 后允许先重建 manifest，再立即 `--check`。这样开发分支仍保持完整性纪律，正式发布不会因生成型元数据遗漏新增文档而跳过真正的编译测试。

## 3. 异步后台任务必须有生命周期

任何会写 Runtime/缓存文件的短生命周期 goroutine 都必须经 `goBackground()` 注册到 `backgroundWG`。测试在退出前 `waitBackground()`，避免测试函数已经返回、TempDir 开始清理时后台任务重新创建目录/文件。

长生命周期 poller、HTTP Serve loop、菜单进程 watcher 不进入该 WaitGroup，否则测试/退出将永远等待。

## 4. CI 与 Release 只能有一套核心流程

`.github/workflows/ci.yml` 和 `.github/workflows/release.yml` 都调用 `scripts/simulate-release.sh --strict-macos`。新增门禁优先写进脚本，再由两个 workflow 复用，避免“一边修了、一边忘记同步”。

## 5. 发布必须验证“最终资产”而非只验证源码

完整链路需要检查：SwiftUI app arm64、bundle version/build、PKG 可读取、ZIP CRC/结构、portable Mach-O arm64、portable ZIP 结构、SHA-256，以及 GitHub Release 上传后的在线回读。

## 6. 错误日志要保留原始证据

`build-release.sh` 保存完整 `xcodebuild-release.log`。构建失败时输出真正编译错误和尾部日志，workflow 无论成功失败都尝试上传日志 artifact，避免只留下 `exit code 65`。
