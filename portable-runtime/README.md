# Portable arm64 delivery runtime

- v1.2.7 同步正式版版本号与 build 127；portable 功能保持当前 source-4 基线，不改动既有代理、状态栏和窗口行为。
- v1.2.5 将状态栏下拉菜单上传/下载速率合并为单行；代理组前后使用分隔线独立成组；窗口标题栏/拖拽区由 52px 收紧为 36px，并改用与整体 Dashboard 协调的标题栏色。
- v1.2.4 新增代理组/代理列表四种排序、当前组测速与共享节点测速缓存；状态栏将各代理组放到顶层菜单，每组均可测速和选择线路。
此目录用于在非 macOS 环境交叉构建可运行的 Apple Silicon 测试/即时安装版，不替代仓库根目录的 SwiftUI/Xcode 正式实现。

- `GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build` 生成 arm64 Mach-O 主进程。
- 主进程仅监听随机 `127.0.0.1` 端口，并用每次启动随机 token 保护本地 API。
- JXA + AppKit/WebKit 提供窗口与状态栏；远端 Mihomo 请求由 Go 进程发送，因此不受 WebKit CORS 限制。
- Profile 非敏感字段写入 `~/Library/Application Support/MihomoCoreManager/settings.json`；Core Secret 使用 macOS Keychain。
- v1.2.3 新增代理切换页：通过 Direct Core Controller URL 读取/切换 rule、global、direct 模式，并展示代理组及详细代理；代理选择由本地 Go bridge 转发到 Mihomo Controller，避免 WebKit CORS 限制。
- v1.2.0 使用 Mihomo Core 管理面板 v4.0.0 Dashboard UI，并继续保留 v1.0.7 菜单栏 JXA 启动稳定性保护。
- v1.2.0 状态栏本体不再依赖 `NSStatusBarButton` 多行 title；改用按钮内 click-forwarding AppKit overlay 与上下两组 `NSTextField`，确保实时网速可见。
- 上传在上、下载在下并靠底部对齐；只显示数字 + 自动单位，不显示箭头。数字列左对齐并固定预留 4 个等宽字符位，单位列独立。
- v1.1.9 已完成的分组下拉菜单保持不变：“服务器 / Core 控制 / 管理与工具 / 状态栏显示”子菜单继续使用 SF Symbols。
- v1.1.8 保留 v1.1.7 异步按钮 busy spinner 与 `cursor: progress`，项目升级仅在远端 `running=false` 且确认任务已结束后恢复。
- v1.1.8 扩大左侧导航整行命中区域并增强按下动画；原生成功通知会在对应按钮动作真正结束后自动收起。
- v1.1.8 修复持久页面首次切换到“设置/运行日志”时加载任务 ID 未变化的问题。
- 状态栏 `显示图标` / `显示运行状态` / `显示网速` 三项独立持久化并可同时开启；旧设置自动迁移 `showIcon=true`。
- `POST /local/subscriptions` 对 v4.0.0 “热重载超时并回滚”增加安全重启回退：停止 Core → 再保存/校验 → 启动 Core；其它 renderer/URL 错误不触发该回退。
- 左侧“管理后端”入口移动到“设置”下方，使用与其它侧栏菜单一致的 43px 行高与 14px 文字；不再显示 M 品牌方块。
- 后端下拉使用名称 + Endpoint + 选中勾的轻量布局，不再重复品牌图标。
- 状态栏网速正常路径使用 `NSStatusBarButton` 内部的 click-forwarding 原生 overlay + 独立标签渲染；不修改 crash-prone 的 NSButtonCell 多行属性，不使用 `attributedTitle` 或 `CATextLayer`，渲染失败时自动安全降级。
- `status.json` 带本地更新时间，菜单栏可检测过期并通过 loopback 状态接口自动恢复。
- 下拉菜单中的上传/下载速度在 v1.2.5 合并为一个单行只读菜单项。
- 主菜单栏 JXA shell 异常退出时自动启动最小恢复 shell，并记录 `Runtime/menubar.log`；标题栏 drag strip、集中状态缓存、标准 Edit responder chain、`⌘V`/显式粘贴继续保留。

正式 GitHub Release 由 `.github/workflows/release.yml` 在 macOS arm64 Runner 上构建 SwiftUI App；v1.2.7 继续先通过 `actions/setup-go@v6` 按 `go.mod` 显式配置 Go，再测试并构建本 portable arm64 安装包，默认使用无需 Apple Developer 凭据的 `--unsigned` 发布路径。普通 macOS CI 也执行相同 portable 构建脚本，避免 Release 阶段才发现工具链缺失。
