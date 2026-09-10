# Mihomo Core Manager v1.1.0

v1.1.0 保留 v1.0.9 的状态栏与订阅热重载超时修复，并调整 GitHub Release 流程，使没有 Apple Developer 证书的仓库也能直接完成自动构建与发布。

## GitHub Actions Release 修复

- `macOS Release` 默认改为执行 `bash scripts/build-release.sh --unsigned`。
- 移除 Release workflow 对 Apple Developer ID Application、Installer 证书和 Notary API Key 的强制 Secrets 检查。
- 不再导入 Developer ID 证书，也不会调用签名/公证步骤作为默认发布路径。
- 仍会在 Apple Silicon `macos-15` Runner 上构建 arm64 SwiftUI App。
- 仍会生成 `.zip`、`.pkg`、中文 Release Notes 和 `SHA256SUMS.txt`，并自动创建/更新 GitHub Release。
- 在线回读 Release 资产并验证 SHA-256 的发布后校验继续保留。

## 未签名版本说明

默认 Release 产物不包含 Developer ID / Apple Notary 身份。App 在构建脚本中使用 ad-hoc 签名，`.pkg` 不使用 Developer ID Installer 签名，因此在其它 Mac 上首次安装/启动时可能触发 Gatekeeper 提示。

如以后配置了 Apple Developer 证书，`scripts/build-release.sh --signed` 路径仍然保留，可重新启用 Developer ID 签名与 Apple 公证。

## 继续保留

- 图标、运行状态、实时网速三项可同时显示。
- 订阅“保存并应用”在明确的热重载超时并回滚场景下自动执行安全重启回退。
- 菜单栏 Recovery Shell、`Runtime/menubar.log`、Core Secret 粘贴、窗口拖动、多服务器、集中状态缓存。
- arm64 架构校验、源码完整性门禁与 Release SHA-256 校验。

版本：App v1.1.0 (build 110)，API 兼容基线 v4.0.0。
