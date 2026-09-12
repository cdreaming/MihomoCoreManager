# macOS v1.2.11 发布流程

v1.2.11 以 v1.2.10 为功能基线，并保留 v1.2.5 fixed5 起已验证的发布硬门禁。不要把 CI、Release、preflight 拆成彼此不同的检查链路。

1. 确认 `VERSION=1.2.11`、Xcode `MARKETING_VERSION=1.2.11`、`CURRENT_PROJECT_VERSION=1211`。
2. 修改源码后执行 `python3 scripts/build-source-manifest.py --write`，并提交更新后的 `SOURCE-SHA256SUMS.txt`。
3. 执行 `python3 scripts/validate-source.py` 与 `python3 scripts/build-source-manifest.py --check`。
4. 执行 `python3 scripts/release-preflight.py`；开发机可再执行 `bash scripts/simulate-release.sh`。
5. Apple Silicon macOS / GitHub `macos-15` 必须执行同一套 `bash scripts/simulate-release.sh`。脚本在 arm64 macOS 上会自动继续执行 `release-preflight.py --strict-macos` 和真实 Xcode Release build。
6. 原生构建统一使用 `bash scripts/build-release.sh --unsigned`。脚本固定 `SWIFT_ENABLE_BATCH_MODE=NO`，完整保存 `build/xcodebuild-release.log`，失败时回显真正的 `error:` / `fatal error:`。
7. strict macOS semantic probe 必须通过 `xcrun --sdk macosx swiftc`、当前 Xcode SDK 与 `arm64-apple-macos14.0`。
8. portable runtime 必须通过目标竞态回归、随机顺序测试、race、vet、Darwin/arm64 runtime/test binary 交叉编译、portable ZIP/版本/Mach-O 校验。
9. GitHub `.pkg` 重点回归：状态栏图标/状态/双行网速可按开关显示；代理组显示当前选择；菜单背景为参考色 #1A1A1D；超屏可滚动但完全无系统滚动条；代理组显示 `组名 · 当前线路`；主窗口显示自身程序版本。
10. CI 与正式 Release 都只调用 `scripts/simulate-release.sh`。
11. 推送新 tag `v1.2.11`，或在 `macOS Release` workflow 中输入 `1.2.11`。不要移动已经存在且指向旧 commit 的 tag。
12. GitHub Release 上传完成后，workflow 会在线重新下载全部资产并使用 `SHA256SUMS.txt` 回放校验。

正式发布资产：

- `MihomoCoreManager-v1.2.11-arm64.pkg`
- `MihomoCoreManager-v1.2.11-arm64.zip`
- `MihomoCoreManager-v1.2.11-arm64-portable-installer.zip`
- `release_v1.2.11_notes_zh-CN.md`
- `SHA256SUMS.txt`

v1.2.4 / v1.2.5 事故沉淀规则详见 `docs/RELEASE-GUARDRAILS.md`。
