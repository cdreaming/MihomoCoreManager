# macOS v1.1.9 发布流程

1. 确认 `VERSION=1.1.9`、Xcode `MARKETING_VERSION=1.1.9`、`CURRENT_PROJECT_VERSION=119`。
2. 执行 `python3 scripts/validate-source.py`。
3. 执行 `python3 scripts/build-source-manifest.py --check`。
4. 推送 tag `v1.1.9`，或在 `macOS Release` workflow 中输入 `1.1.9`。

正式发布资产：`MihomoCoreManager-v1.1.9-arm64.pkg`、`MihomoCoreManager-v1.1.9-arm64.zip`、`release_v1.1.9_notes_zh-CN.md`、`SHA256SUMS.txt`。
