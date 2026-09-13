# QA v1.2.6

## 发布门禁

- [ ] `python3 scripts/build-source-manifest.py --check` 在 PR/main checkout 中通过。
- [ ] `python3 scripts/release-preflight.py --strict-macos` 在 Apple Silicon macOS Runner 上通过。
- [ ] `bash scripts/simulate-release.sh --strict-macos` 完整通过。
- [ ] Xcode Release build 使用 `SWIFT_ENABLE_BATCH_MODE=NO`，产物仅包含 arm64。
- [ ] `build/xcodebuild-release.log` 在失败时可作为 CI artifact 回读。
- [ ] `.pkg`、SwiftUI `.zip`、portable installer 与 release notes 均被 `SHA256SUMS.txt` 覆盖并可回读校验。

## Swift / Xcode

- [ ] 全部 Swift 源文件以 Swift 5 模式解析通过。
- [ ] `Models.swift` 使用当前 Xcode macOS SDK 和 `arm64-apple-macos14.0` target 通过 typecheck。
- [ ] `ProxySortOption` 保持 `Hashable`，排序 Picker 与代理详情拆分不回退。
- [ ] `proxy?.alive` 使用显式 Optional pattern，不能恢复 `case true / nil / false`。

## Go / portable

- [ ] `TestGroupDelayCacheDecoratesSharedProxyData` 连续 300 次通过，无 TempDir cleanup race。
- [ ] 全套 Go 测试随机顺序重复 10 次通过。
- [ ] `go test -race ./...` 通过。
- [ ] `go vet ./...` 通过。
- [ ] Darwin/arm64 test binary 与 portable runtime 均验证为 thin Mach-O arm64。
- [ ] portable ZIP CRC、Info.plist 版本/build 与 SHA-256 校验通过。

## 功能回归

- [ ] v1.2.5 状态栏线路选择后缀立即刷新。
- [ ] v1.2.5 完整左右布局、隐藏视觉标题栏保持不变。
- [ ] v1.2.4 Cloudflare 530/1033 快照回退、provider-only 节点、嵌套组与延时逻辑不回归。
