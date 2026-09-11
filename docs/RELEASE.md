# macOS v1.2.6 发布流程

1. 确认 `VERSION=1.2.6`、Xcode `MARKETING_VERSION=1.2.6`、`CURRENT_PROJECT_VERSION=126`，portable runtime 同为 `1.2.6 / 126`。
2. 更新源码后执行 `python3 scripts/build-source-manifest.py --write` 并提交新的 `SOURCE-SHA256SUMS.txt`。
3. 本地执行 `bash scripts/simulate-release.sh`；它会完成跨平台可执行的 Swift parse、Go 压力/竞态检查、Darwin arm64 交叉编译和 portable 产物校验。
4. 提交到 `main`，等待 `macOS CI / Apple Silicon arm64 full release simulation` 通过。该 job 在 `macos-15` arm64 Runner 上运行 `bash scripts/simulate-release.sh --strict-macos`，其中包含真实 Xcode Release build。
5. CI 绿灯后创建新 tag `v1.2.6`，或从 `macOS Release` workflow 输入 `1.2.6`。不要移动已存在/失败/已发布的旧 tag；若 tag 已存在但不指向当前 commit，workflow 会拒绝发布。
6. Release workflow 会再次从精确 checkout 完整模拟发布，通过后才创建/更新 GitHub Release，并在线回读所有资产执行 SHA-256 校验。

正式发布资产：`MihomoCoreManager-v1.2.6-arm64.pkg`、`MihomoCoreManager-v1.2.6-arm64.zip`、`MihomoCoreManager-v1.2.6-arm64-portable-installer.zip`、`release_v1.2.6_notes_zh-CN.md`、`SHA256SUMS.txt`。
