# macOS v1.2.1 发布流程

1. 确认 `VERSION=1.2.1`、Xcode `MARKETING_VERSION=1.2.1`、`CURRENT_PROJECT_VERSION=121`。
2. 执行 `python3 scripts/validate-source.py`。
3. 执行 `python3 scripts/build-source-manifest.py --check`。
4. 推送新 tag `v1.2.1`，或在 `macOS Release` workflow 中输入 `1.2.1`。不要把已发布的 `v1.2.0` tag 强制移动到新 commit。

正式发布资产：`MihomoCoreManager-v1.2.1-arm64.pkg`、`MihomoCoreManager-v1.2.1-arm64.zip`、`MihomoCoreManager-v1.2.1-arm64-portable-installer.zip`、`release_v1.2.1_notes_zh-CN.md`、`SHA256SUMS.txt`。
