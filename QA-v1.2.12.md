# QA v1.2.12

## 版本与主窗口

- [ ] `VERSION=1.2.12`。
- [ ] Xcode `MARKETING_VERSION=1.2.12`、`CURRENT_PROJECT_VERSION=1212`。
- [ ] portable regression runtime `appVersion=1.2.12`、`buildNumber=1212`。
- [ ] 左上版本区第一行显示 `本程序版本：v1.2.12`。
- [ ] 第二行显示 `Core 版本：<实际 Core 版本>`。
- [ ] 第三行显示 `Core 面板：<远端 management_panel 版本>`。
- [ ] 第四行显示 `MetaCubeXD：<实际版本>`。
- [ ] 不再出现旧标签 `程序版本`，也不得用 App 版本覆盖 Core 面板版本。

## 单一原生 App 发布一致性

- [ ] GitHub macOS arm64 上 `bash scripts/simulate-release.sh` 完整通过。
- [ ] `dist/NATIVE-APP-MANIFEST.json` 存在并包含 `tree_sha256`。
- [ ] `dist/RELEASE-PROVENANCE.txt` 的 `source_commit` 等于 Release commit。
- [ ] `MihomoCoreManager-v1.2.12-arm64.zip` 解包后的 App 与 manifest 一致。
- [ ] `MihomoCoreManager-v1.2.12-arm64-native-installer.zip` 中 App 与 App ZIP 完全一致。
- [ ] `MihomoCoreManager-v1.2.12-arm64.pkg` 解包后的 App 与 App ZIP 完全一致。
- [ ] `scripts/verify-native-release-parity.sh dist` 通过并输出一个统一 App tree SHA-256。
- [ ] GitHub Release 只发布 `dist/*` 正式原生资产，不发布 `arm64-portable-installer.zip`。
- [ ] GitHub Release 在线回读后再次执行 parity verifier 成功。

## UI 回归

- [ ] native installer ZIP 与 PKG 在同一台 Mac 上状态栏/主窗口 UI 一致。
- [ ] 状态栏背景仍为参考色 `#1A1A1D`。
- [ ] 超屏可滚动但无右侧系统滚动条。
- [ ] 代理组显示 `组名 · 当前线路`，打开菜单时能刷新 Controller `now`。
- [ ] 状态栏图标/状态/双行网速开关正常。
- [ ] 关闭主窗口后从状态栏重新打开仍可移动。
