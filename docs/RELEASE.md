# macOS v1.1.8 发布流程

1. 确认 `VERSION=1.1.8`、Xcode `MARKETING_VERSION=1.1.8`、`CURRENT_PROJECT_VERSION=118`。
2. 执行 `python3 scripts/validate-source.py` 与 `python3 scripts/build-source-manifest.py --check`。
3. 在 Apple Silicon macOS + Xcode 16.4（或兼容版本）执行 `bash scripts/build-release.sh --unsigned`。
4. 推送 tag `v1.1.8`，或在 `macOS Release` workflow 中输入 `1.1.8`。

正式发布资产：`MihomoCoreManager-v1.1.8-arm64.pkg`、`MihomoCoreManager-v1.1.8-arm64.zip`、`release_v1.1.8_notes_zh-CN.md`、`SHA256SUMS.txt`。

在非 macOS 构建机上可执行 `bash scripts/build-portable-installer.sh`，生成基于 portable runtime 的 Apple Silicon 即时安装包；该包用于安装/测试，不冒充 Xcode 构建的正式 SwiftUI `.pkg`。
