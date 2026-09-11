# macOS v1.2.2 发布流程

1. 确认 `VERSION=1.2.2`、Xcode `MARKETING_VERSION=1.2.2`、`CURRENT_PROJECT_VERSION=122`。
2. 执行 `python3 scripts/validate-source.py`。
3. 执行 `python3 scripts/build-source-manifest.py --check`。
4. 确认 `.github/workflows/release.yml` 与 `.github/workflows/ci.yml` 均使用 `actions/setup-go@v6` + `portable-runtime/go.mod`，Release 不再依赖 Runner 预装 Go。
5. 推送新 tag `v1.2.2`，或在 `macOS Release` workflow 中输入 `1.2.2`。不要移动已经失败/发布过的旧 tag。

正式发布资产：`MihomoCoreManager-v1.2.2-arm64.pkg`、`MihomoCoreManager-v1.2.2-arm64.zip`、`MihomoCoreManager-v1.2.2-arm64-portable-installer.zip`、`release_v1.2.2_notes_zh-CN.md`、`SHA256SUMS.txt`。
