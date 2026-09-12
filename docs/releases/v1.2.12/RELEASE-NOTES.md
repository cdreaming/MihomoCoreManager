# Mihomo Core Manager v1.2.12

v1.2.12 重点解决正式 GitHub `.pkg` 与此前用于本地验收的另一套 portable UI 可能出现视觉/行为差异的问题，并按要求调整主窗口版本信息。

## 版本

- App: `1.2.12`
- Build: `1212`
- Xcode `MARKETING_VERSION`: `1.2.12`
- Xcode `CURRENT_PROJECT_VERSION`: `1212`
- portable regression runtime: `1.2.12 / 1212`

## 主窗口版本区

左上版本信息改为固定四行：

1. `本程序版本`：读取当前 App `CFBundleShortVersionString`。
2. `Core 版本`：读取远端 Core 版本。
3. `Core 面板`：读取远端 `versions.management_panel`。
4. `MetaCubeXD`：读取远端 MetaCubeXD 版本。

App 版本和 Core 面板版本不再互相替代。

## One Canonical Native App

此前 portable installer 与 GitHub `.pkg` 分别来自 Go/AppKit/Web 和 SwiftUI/AppKit 两套 UI，实现同步并不能证明二进制 UI 一致。v1.2.12 起正式 Release 改为：

- Xcode Release 只编译一次原生 App。
- App 完成签名/公证后冻结为唯一 `build/Canonical/MihomoCoreManager.app`。
- App ZIP、native installer ZIP 和 PKG 全部只封装这同一份冻结 App。
- `NATIVE-APP-MANIFEST.json` 对 App bundle 内所有文件/符号链接做内容级 SHA-256 清单。
- `verify-native-release-parity.sh` 在上传前和 GitHub Release 在线回读后，重新解包三种容器并逐项比较 manifest；任何差异都会阻止发布。
- `RELEASE-PROVENANCE.txt` 记录 source commit、Xcode/Swift、App tree hash 和 executable hash。
- portable installer 不再作为正式 GitHub Release 资产，只保留为 CI regression artifact。

因此，用 `MihomoCoreManager-v1.2.12-arm64-native-installer.zip` 验收的 UI，就是 `.pkg` 中同一个原生 App 的 UI。

## 正式 GitHub Release 资产

- `MihomoCoreManager-v1.2.12-arm64.pkg`
- `MihomoCoreManager-v1.2.12-arm64.zip`
- `MihomoCoreManager-v1.2.12-arm64-native-installer.zip`
- `NATIVE-APP-MANIFEST.json`
- `RELEASE-PROVENANCE.txt`
- `release_v1.2.12_notes_zh-CN.md`
- `SHA256SUMS.txt`
