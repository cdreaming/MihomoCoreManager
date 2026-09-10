# macOS v1.1.6 发布流程

1. 确认 `VERSION=1.1.6`、Xcode `MARKETING_VERSION=1.1.6`、`CURRENT_PROJECT_VERSION=116`。
2. 执行 `python3 scripts/validate-source.py` 与 `python3 scripts/build-source-manifest.py --check`。
3. 在 Apple Silicon macOS + Xcode 16.4（或兼容版本）执行 `bash scripts/build-release.sh --unsigned`。
4. 推送 tag `v1.1.6`，或在 `macOS Release` workflow 中输入 `1.1.6`。

发布资产：`MihomoCoreManager-v1.1.6-arm64.pkg`、`MihomoCoreManager-v1.1.6-arm64.zip`、`release_v1.1.6_notes_zh-CN.md`、`SHA256SUMS.txt`。
