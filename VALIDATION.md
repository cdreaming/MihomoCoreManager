# Validation

v1.2.6 本地/跨平台预检：

```bash
python3 scripts/build-source-manifest.py --check
python3 scripts/release-preflight.py
bash scripts/simulate-release.sh
```

Apple Silicon macOS + Xcode 16.x / GitHub `macos-15` 的正式发布模拟：

```bash
bash scripts/simulate-release.sh --strict-macos
```

严格模式覆盖：source validation、manifest 自修复与复核、Shell/Python 语法、全部 Swift 5 parse、当前 Xcode macOS SDK 下 `Models.swift` typecheck、Xcode Release settings、Go 300 次目标回归、全套 shuffle、race、vet、Darwin/arm64 test binary、portable installer、真实 Xcode Release build、arm64 架构、bundle version/build、PKG/ZIP、SHA-256。

PR/main CI 在严格模拟前额外执行一次 `build-source-manifest.py --check`，因此仓库内 stale manifest 仍会被拦截；Release 则在精确 checkout 后自动重建生成型 manifest，避免新增说明文件阻断真实编译。
