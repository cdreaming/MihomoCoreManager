# macOS v1.2.12 发布流程

v1.2.12 引入 **One Canonical Native App** 发布契约。正式 GitHub Release 不再同时发布另一套 portable UI；所有给用户安装/验收的正式资产都必须包含同一份 Xcode 原生 App。

1. 确认 `VERSION=1.2.12`、Xcode `MARKETING_VERSION=1.2.12`、`CURRENT_PROJECT_VERSION=1212`。
2. 修改源码后执行 `python3 scripts/build-source-manifest.py --write` 并提交 `SOURCE-SHA256SUMS.txt`。
3. 执行 `python3 scripts/validate-source.py`、`python3 scripts/build-source-manifest.py --check`、`python3 scripts/release-preflight.py`。
4. Apple Silicon macOS / GitHub `macos-15` 统一执行 `bash scripts/simulate-release.sh`。
5. 原生发布只调用 `bash scripts/build-release.sh --unsigned`（需要签名时用 `--signed`）。Xcode 只编译一次；签名/公证 App 完成后复制到 `build/Canonical/MihomoCoreManager.app` 并冻结为唯一正式 App。
6. `build-release.sh` 从同一冻结 App 生成：App ZIP、native installer ZIP、PKG；不得为任一容器重新编译、重新生成 UI 或重新签名 App。
7. `scripts/app-bundle-manifest.py` 生成 `NATIVE-APP-MANIFEST.json`，覆盖 App 内所有普通文件内容和符号链接目标。
8. `scripts/verify-native-release-parity.sh` 解包 App ZIP、native installer ZIP、PKG，逐文件比较 manifest，并验证 `CFBundleShortVersionString=1.2.12`、`CFBundleVersion=1212`、arm64 与 codesign 完整性。任一差异直接失败。
9. `RELEASE-PROVENANCE.txt` 记录 source commit、Xcode/Swift、App tree SHA-256、主二进制 SHA-256；GitHub 在线回读 Release 后必须再次运行 parity verifier。
10. portable runtime 继续执行 Go stress/race/vet/Darwin-arm64 交叉编译，但其安装 ZIP只作为 CI regression artifact，不上传正式 GitHub Release。
11. 推送 tag `v1.2.12`，或在 `macOS Release` workflow 输入 `1.2.12`。不要移动已存在且指向旧 commit 的 tag。

正式发布资产：

- `MihomoCoreManager-v1.2.12-arm64.pkg`
- `MihomoCoreManager-v1.2.12-arm64.zip`
- `MihomoCoreManager-v1.2.12-arm64-native-installer.zip`
- `NATIVE-APP-MANIFEST.json`
- `RELEASE-PROVENANCE.txt`
- `release_v1.2.12_notes_zh-CN.md`
- `SHA256SUMS.txt`

**UI 验收规则：**先安装/运行 `arm64-native-installer.zip` 中的 App 验收 UI；正式 `.pkg` 必须通过 parity gate 证明包含同一 App。这样在同一台 macOS 机器上，两种安装方式的程序代码、资源和 UI 实现完全相同。
