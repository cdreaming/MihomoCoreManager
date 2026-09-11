# macOS v1.2.5 发布流程

1. 确认 `VERSION=1.2.5`、Xcode `MARKETING_VERSION=1.2.5`、`CURRENT_PROJECT_VERSION=125`。
2. 执行 `python3 scripts/validate-source.py`。
3. 执行 `python3 scripts/build-source-manifest.py --check`。
4. 执行 `python3 scripts/release-preflight.py`；开发机可再执行 `bash scripts/simulate-release.sh`。
5. Apple Silicon macOS / GitHub `macos-15` 必须执行 `python3 scripts/release-preflight.py --strict-macos`。该步骤会校验 arm64 Runner、Xcode/Swift 工具链和 Release build settings。
6. 正式 SwiftUI 构建统一使用 `bash scripts/build-release.sh --unsigned`。脚本固定 `SWIFT_ENABLE_BATCH_MODE=NO`，保存 `build/xcodebuild-release.log`，失败时在日志末尾重新输出编译器 `error:`。
7. `.github/workflows/release.yml` 与 `.github/workflows/ci.yml` 均使用 `actions/setup-go@v6` + `portable-runtime/go.mod`，Release 不依赖 Runner 预装 Go。
8. macOS CI 必须先通过真实 Xcode Release 编译、portable Go 测试/构建和 arm64 架构检查；失败时自动上传 Xcode diagnostic log。
9. 推送新 tag `v1.2.5`，或在 `macOS Release` workflow 中输入 `1.2.5`。不要移动已经失败/发布过的旧 tag。
10. Release 创建后在线重新下载资产并执行 `SHA256SUMS.txt` 校验。

正式发布资产：

- `MihomoCoreManager-v1.2.5-arm64.pkg`
- `MihomoCoreManager-v1.2.5-arm64.zip`
- `MihomoCoreManager-v1.2.5-arm64-portable-installer.zip`
- `release_v1.2.5_notes_zh-CN.md`
- `SHA256SUMS.txt`

v1.2.4 事故沉淀规则详见 `docs/RELEASE-GUARDRAILS.md`。其中包括 Xcode 16.4 对 `Bool?` switch 的穷尽性差异、SwiftUI 大型 result builder 拆分、显式 Picker tag / Hashable、macOS 14 `onChange` API 和失败日志保留规则。
