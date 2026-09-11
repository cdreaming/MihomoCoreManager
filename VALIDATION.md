# Validation

v1.2.7 发布前执行：

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
python3 scripts/release-preflight.py
bash scripts/simulate-release.sh
```

Apple Silicon macOS / GitHub `macos-15` 的 `simulate-release.sh` 还会自动执行：

```bash
python3 scripts/release-preflight.py --strict-macos
bash scripts/build-release.sh --unsigned
(cd build/release-simulation-verify && shasum -a 256 -c SHA256SUMS.txt)
```

重点门禁：

- App/Xcode/portable 版本一致为 v1.2.7 / build 127。
- Xcode Release 固定 `arm64`、macOS 14.0、Swift 5、`SWIFT_ENABLE_BATCH_MODE=NO`。
- 14 个 Swift 文件必须进入 Xcode project / Sources phase，并逐文件 Swift 5 parse；`Models.swift` 在 macOS 上使用当前 Xcode macOS SDK + `arm64-apple-macos14.0` 做 semantic typecheck。
- v1.2.4 的 `Bool?` Optional switch、`ProxySortPicker`、大型 SwiftUI result-builder 拆分、`Hashable`、具体 history 中间类型、macOS 14 `onChange` 写法不得回退。
- Xcode 完整输出保存到 `build/xcodebuild-release.log`；CI/Release 失败时上传日志。
- `SOURCE-SHA256SUMS.txt` 在普通 CI 严格检查；正式 Release 基于精确 checkout 自愈后立即复核，strict preflight 再次自检。
- portable 自有异步刷新必须由 `backgroundWG + goBackground()` 管理；TempDir 测试在清理前等待后台任务完成。
- portable 目标竞态测试重复、全套 shuffle、race、vet、Darwin/arm64 runtime/test binary 交叉编译、portable ZIP CRC/版本/Mach-O 全部进入发布模拟。
- CI 和 Release 使用同一个 `scripts/simulate-release.sh`，不能恢复为两套手写步骤。
- 原生与 portable 保留 v1.2.7 当前功能：代理即时后缀刷新、状态缓存平滑、Cloudflare 530/1033 快照回退、完整左右布局与安全 HTTP/TLS 策略。

详细规则见 `docs/RELEASE-GUARDRAILS.md`。
