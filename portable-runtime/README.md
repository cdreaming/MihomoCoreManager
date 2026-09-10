# Portable arm64 delivery runtime

此目录用于在非 macOS 环境交叉构建可运行的 Apple Silicon 测试/即时安装版，不替代仓库根目录的 SwiftUI/Xcode 正式实现。

- `GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build` 生成 arm64 Mach-O 主进程。
- 主进程仅监听随机 `127.0.0.1` 端口，并用每次启动随机 token 保护本地 API。
- JXA + AppKit/WebKit 提供窗口与状态栏；远端 Mihomo 请求由 Go 进程发送，因此不受 WebKit CORS 限制。
- Profile 非敏感字段写入 `~/Library/Application Support/MihomoCoreManager/settings.json`；Core Secret 使用 macOS Keychain。
- v1.1.7 使用 Mihomo Core 管理面板 v4.0.0 Dashboard UI，并继续保留 v1.0.7 菜单栏 JXA 启动稳定性保护。
- v1.1.7 异步按钮会保持 busy spinner 与 `cursor: progress`，项目升级仅在远端 `running=false` 且确认任务已结束后恢复。
- 状态栏 `显示图标` / `显示运行状态` / `显示网速` 三项独立持久化并可同时开启；旧设置自动迁移 `showIcon=true`。
- `POST /local/subscriptions` 对 v4.0.0 “热重载超时并回滚”增加安全重启回退：停止 Core → 再保存/校验 → 启动 Core；其它 renderer/URL 错误不触发该回退。
- 左侧“管理后端”入口移动到“设置”下方，使用与其它侧栏菜单一致的 43px 行高与 14px 文字；不再显示 M 品牌方块。
- 后端下拉使用名称 + Endpoint + 选中勾的轻量布局，不再重复品牌图标。
- 状态栏正常路径仍使用 `NSStatusBarButton` 文本显示下载/上传；不修改 crash-prone 的 NSButtonCell 多行属性或 attributedTitle，渲染失败时自动安全降级。
- `status.json` 带本地更新时间，菜单栏可检测过期并通过 loopback 状态接口自动恢复。
- 下拉菜单中的上传/下载速度使用两个独立只读菜单项。
- 主菜单栏 JXA shell 异常退出时自动启动最小恢复 shell，并记录 `Runtime/menubar.log`；标题栏 drag strip、集中状态缓存、标准 Edit responder chain、`⌘V`/显式粘贴继续保留。

正式 GitHub Release 仍由 `.github/workflows/release.yml` 在 macOS arm64 Runner 上构建 SwiftUI App；v1.1.7 默认使用无需 Apple Developer 凭据的 `--unsigned` 发布路径。
