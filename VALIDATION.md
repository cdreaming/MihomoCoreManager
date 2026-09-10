# Validation Report — v1.1.0 macOS App

- App 版本统一为 `1.1.0`，Xcode build number 为 `110`。
- Xcode 工程保持 Apple Silicon `arm64` / macOS 14.0。
- GitHub `macOS Release` 默认执行 `scripts/build-release.sh --unsigned`，不再引用 Apple Developer / Notary Repository Secrets。
- `scripts/build-release.sh --signed` 仍保留 Developer ID 签名、公证与 Installer 签名能力，供以后恢复正式签名发布。
- Release 仍保留 tag / workflow_dispatch 版本一致性检查、源码门禁、GitHub Release 创建/更新、资产上传和在线 SHA-256 校验。
- v1.0.9 的状态栏三项独立控制、菜单栏安全降级 / Recovery Shell、订阅热重载超时安全重启回退继续保留。
- 交付门禁继续覆盖 source validation / manifest、arm64 版本元数据、API/菜单/设置与 Release 工作流关键路径。
