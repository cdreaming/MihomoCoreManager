# Validation Report — v1.0.9 macOS App

- App 版本统一为 `1.0.9`，Xcode build number 为 `109`。
- Xcode 工程保持 Apple Silicon `arm64` / macOS 14.0。
- 状态栏新增独立 `showIcon` 偏好；图标、运行状态、双行网速可以同时启用，portable 旧设置自动迁移为显示图标。
- 状态栏三项全部关闭时自动保留图标，避免菜单栏项目完全不可见。
- portable 状态栏继续避开 v1.0.6 的 CATextLayer / NSButtonCell 多行属性 / attributedTitle 高风险启动路径，并保留 Recovery Shell 与 `Runtime/menubar.log`。
- “订阅管理 → 保存并应用”增加 v4.0.0 热重载 timeout 专用回退：仅在“热重载失败 + timeout/超时 + 已恢复/回滚”同时成立时执行 `stop → save/validate → start`。
- 新增 Go 回归测试模拟 v4.0.0 热重载超时，验证订阅事务会重试一次且动作顺序严格为 `stop,start`。
- 其它订阅 URL/renderer/校验错误不触发安全重启。
- v1.0.8 的“管理后端”等宽下拉、Core Secret `⌘V` / 显式粘贴、窗口拖动、设置 Tab、多服务器、状态缓存与正式 Release 流程继续保留。
- 交付门禁包括 source validation/manifest、Go test/vet、Swift parse、JavaScript syntax、YAML/Plist、shell 语法、Mach-O arm64 与 ZIP 完整性。
