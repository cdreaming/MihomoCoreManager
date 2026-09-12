# Validation

v1.2.12 发布前执行：

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
python3 scripts/release-preflight.py
bash scripts/simulate-release.sh
```

Apple Silicon macOS / GitHub `macos-15` 的 `simulate-release.sh` 还会自动执行：

```bash
python3 scripts/release-preflight.py --strict-macos
bash scripts/build-release.sh --unsigned
bash scripts/verify-native-release-parity.sh dist
(cd build/release-simulation-verify && shasum -a 256 -c SHA256SUMS.txt)
```

重点门禁：

- App/Xcode/portable regression runtime 版本一致为 v1.2.12 / build 1212。
- 主窗口左上版本区顺序固定为：`本程序版本` → `Core 版本` → `Core 面板` → `MetaCubeXD`。
- `本程序版本` 只读取 `CFBundleShortVersionString`；`Core 面板` 只读取远端 `versions.management_panel`。
- Xcode Release 固定 arm64、macOS 14.0、Swift 5、`SWIFT_ENABLE_BATCH_MODE=NO`；所有 Swift 文件进入 Xcode Sources phase。
- Xcode 只编译一次，签名完成后冻结 `build/Canonical/MihomoCoreManager.app`；正式 ZIP、native installer ZIP、PKG 只从该 App 打包。
- `NATIVE-APP-MANIFEST.json` 对 App bundle 全树做内容级 SHA-256；`verify-native-release-parity.sh` 必须证明三个正式容器解包后的 App manifest 完全一致。
- GitHub Release 只上传 `dist/*`，禁止发布 `dist-portable/*` 或 `arm64-portable-installer.zip`。
- Release 在线回读后必须验证 `SHA256SUMS.txt`、`RELEASE-PROVENANCE.txt` 的 source commit，并再次执行 native parity verifier。
- portable runtime 继续作为 regression target 执行目标竞态测试、shuffle、race、vet 与 Darwin/arm64 交叉编译，但不作为正式 UI 验收包。
- 保留 v1.2.11 状态栏参考背景 `#1A1A1D`、隐藏系统滚动条、`组名 · 当前线路`、`/proxies + /group` 动态 now 刷新。
- 保留 v1.2.8 窗口生命周期门禁：`releasedWhenClosed=false`、`ensureWindowUsable()`、恢复模式 drag strip 与主状态栏单次自动重启。

详细规则见 `docs/RELEASE-GUARDRAILS.md`。
