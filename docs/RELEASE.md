# macOS v1.0.9 发布流程

1. 确认 `VERSION` 为 `1.0.9`，Xcode `MARKETING_VERSION=1.0.9`、`CURRENT_PROJECT_VERSION=109`。
2. 执行 `python3 scripts/validate-source.py` 与 `python3 scripts/build-source-manifest.py --check`。
3. 推送 tag `v1.0.9`，或在 `macOS Release` workflow 中手工输入 `1.0.9`。
4. Release runner 必须为 Apple Silicon；工作流会执行 arm64 Xcode Release 构建、Developer ID Application 签名、公证、Staple，再用 Developer ID Installer 生成 `.pkg`。
5. 发布前会再次验证 Mach-O 架构、签名、公证结果和 SHA-256。

发布资产：`MihomoCoreManager-v1.0.9-arm64.pkg`、`MihomoCoreManager-v1.0.9-arm64.zip`、`release_v1.0.9_notes_zh-CN.md`、`SHA256SUMS.txt`。

即时安装包（本对话内生成）属于本地开发交付，不具备 Developer ID / Apple Notary 身份；正式公开发布以 GitHub Release workflow 产物为准。
