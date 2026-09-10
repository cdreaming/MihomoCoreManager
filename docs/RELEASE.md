# macOS v1.1.4 发布流程

1. 确认 `VERSION` 为 `1.1.4`，Xcode `MARKETING_VERSION=1.1.4`、`CURRENT_PROJECT_VERSION=114`。
2. 执行 `python3 scripts/validate-source.py` 与 `python3 scripts/build-source-manifest.py --check`。
3. 推送 tag `v1.1.4`，或在 `macOS Release` workflow 中手工输入 `1.1.4`。
4. Release runner 必须为 Apple Silicon；工作流默认执行 `bash scripts/build-release.sh --unsigned`，无需配置 Apple Developer / Notary Secrets。
5. 构建脚本会生成 arm64 App、ad-hoc 签名的 `.zip`、未使用 Developer ID Installer 签名的 `.pkg`、Release Notes 与 SHA-256 清单。
6. GitHub Release 创建/更新后，工作流会重新下载在线资产并执行 `shasum -a 256 -c SHA256SUMS.txt`。

发布资产：`MihomoCoreManager-v1.1.4-arm64.pkg`、`MihomoCoreManager-v1.1.4-arm64.zip`、`release_v1.1.4_notes_zh-CN.md`、`SHA256SUMS.txt`。

> 注意：v1.1.4 默认发布产物没有 Developer ID / Apple Notary 身份，首次安装或启动时可能触发 macOS Gatekeeper 提示。
