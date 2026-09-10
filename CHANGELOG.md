# Changelog

## v1.1.3

- 基于 v1.1.2 统一布局修复版发布正式升级版本。
- App 版本升级为 v1.1.3，Xcode build number 与 portable build number 统一为 113。
- 保留 v1.1.2 的紧凑标题栏、页面统一布局和 v1.0.9 菜单栏样式，不引入额外 UI 回退。
- 保留 v1.1.1 以来的管理后端选择器、性能优化、portable runtime 与 unsigned Release 流程。

## v1.1.2

- 修复 v1.1.1 原生 SwiftUI 菜单栏界面回归，继续使用 v1.0.9 已验证稳定的菜单栏布局与样式。
- 优化主窗口标题栏：隐藏标准标题文字与厚重标题栏底板，内容延伸到标题栏区域，减少顶部无效占高。
- 保留 macOS 原生红黄绿窗口控制与拖拽行为；左侧品牌区增加最小安全间距，避免与窗口按钮重叠。
- 保留 v1.1.1 的窗口行为、管理后端选择器、性能优化、portable runtime 与 unsigned Release 流程。
- App 版本升级为 v1.1.2，Xcode build number 与 portable build number 统一为 112。

## v1.1.1

- 修复原生 SwiftUI 状态栏标签过宽、左右留白偏多的问题。
- 修复双行实时网速在菜单栏内上下不居中的问题，并改为更稳定的 SF Symbols 箭头布局。
- 将状态栏运行状态文案压缩为 `On / Off / Wait`，减少宽度占用。
- App 版本升级为 v1.1.1，Xcode build number 为 111；继续保留 v1.1.0 的无需 Apple Secrets 的自动 Release 流程。

## v1.1.0

- 修复 GitHub Actions `macOS Release` 因缺少 Apple Developer / Notary Secrets 而在构建前直接失败的问题。
- 默认 Release 改为 `scripts/build-release.sh --unsigned`，无需配置 Developer ID Application、Developer ID Installer 或 Notary API Key。
- Release 仍生成 arm64 `.zip`、`.pkg`、中文发布说明与 `SHA256SUMS.txt`，并自动创建/更新 GitHub Release、在线回读校验 SHA-256。
- `scripts/build-release.sh --signed` 正式签名/公证路径继续保留，后续获得 Apple Developer 证书后可重新启用。
- App 版本升级为 v1.1.0，Xcode build number 为 110；其余功能保持 v1.0.9 行为。

## v1.0.9

- 状态栏显示改为三项独立控制：`显示图标`、`显示运行状态`、`显示网速` 可同时开启；默认保留图标，升级旧配置时自动迁移 `showIcon=true`。
- portable 状态栏在保持 v1.0.7 稳定性保护的前提下支持图标 + 文本共存；不恢复 CATextLayer、NSButtonCell 多行属性或 attributedTitle 高风险路径。
- 修复“订阅管理 → 保存并应用”在远端 Mihomo `/configs?force=true` 热重载超时时直接失败的问题。
- 对 Mihomo Core 管理面板 v4.0.0 的事务语义增加兼容回退：仅当远端明确返回“热重载失败 + timeout/超时 + 已回滚”时，自动执行 `停止 Core → 再次保存/校验 → 启动 Core`，确保新配置真正生效。
- 对其它订阅 URL/renderer/校验错误保持原有失败语义，不会盲目重启 Core；失败时尽量恢复原运行状态并给出简洁中文错误。
- 保留 v1.0.8 的“管理后端”等宽下拉、v1.0.7 的启动稳定性与 Recovery Shell。

## v1.0.8

- 按实际界面反馈收窄“管理后端”下拉菜单：portable Dashboard 的下拉层从固定 304px 改为 `width: 100%`，与侧栏“管理后端”触发器严格等宽，不再覆盖到右侧主内容区。
- 原生 SwiftUI 的后端 Popover 同步从 304pt 收窄为 206pt，对应 230pt 侧栏扣除左右各 12pt 的导航内边距。
- 保留 v1.0.7 的启动稳定性修复、状态栏安全降级、Recovery Shell 与诊断日志。
- Core Secret 粘贴、窗口拖动、设置 Tab、多服务器与状态缓存继续保留。

## v1.0.7

- 紧急修复 v1.0.6 即时安装版启动后闪退：移除启动阶段对 `NSStatusBarButton` 的 `NSButtonCell` 多行属性修改与 `attributedTitle` 基线调整。
- 状态栏渲染改为“安全优先”路径：仍保留下载在上、上传在下的双行标题尝试；任何渲染异常都会自动降级为单行状态/网速，不再让菜单栏脚本退出。
- portable 宿主不再把菜单栏脚本异常退出直接等同于 App 退出；主菜单栏 shell 异常时自动启动最小恢复 shell，主窗口仍可继续打开和管理。
- 新增 `~/Library/Application Support/MihomoCoreManager/Runtime/menubar.log`，用于记录 JXA/AppKit 启动异常，方便后续定位真实 macOS 差异。
- 保留 v1.0.6 的侧栏“管理后端”布局、无 M 方块图标、窗口拖动、设置 Tab、Core Secret 粘贴和状态缓存。

## v1.0.5

- 左侧后端选择器再次重构：加入“管理后端”分区标签，触发器升级为 64pt/px 高度，使用与主品牌一致的 M 渐变图标、产品名、服务器名、端点和独立展开按钮。
- 后端下拉面板加宽，服务器行提升到 60pt/px，当前项使用 Dashboard 强调态；“未设置 Core Secret”改成独立提示标记，不再挤占服务器名称导致省略号。
- portable Web UI 下拉宽度固定为 292px，解决侧栏过窄时服务器名称/端点被过度截断的问题。
- 修复即时安装版状态栏网速无法显示：移除 v1.0.4 依赖运行时绘制 NSImage 的方案，改为在 NSStatusBarButton 图层中使用 QuartzCore/CATextLayer 直接绘制状态区和上下两行速度区。
- 状态栏状态点、Running/Stopped/Offline 与网速使用独立布局区域；速度继续保持“↑ 上传 / ↓ 下载”上下排列。
- 状态快照增加本地更新时间戳；菜单栏检测快照缺失/过期时自动通过本地 loopback API 恢复，避免状态文件读取异常后一直停留在 0 B/s 或空白。
- 下拉菜单中的上传、下载速度拆成两个独立只读菜单项，确保菜单内也能稳定显示实时值。
- 保留 v1.0.4 的窗口拖动、v1.0.3 的流畅度优化与设置 Tab、v1.0.1 的 Core Secret 粘贴修复。

## v1.0.4

- 修复窗口拖动：原生窗口明确恢复 `isMovable`，portable WebKit 壳新增透明 AppKit 标题栏拖动层，并使用 `performWindowDragWithEvent:`，标题栏可像正常 macOS 窗口一样拖动。
- 左侧 Mihomo Core 后端选择器重做：触发框高度提升到 54pt/px，图标、名称、主机信息和箭头按 Dashboard 视觉统一。
- 原生后端下拉由紧凑系统 `Menu` 改为 Dashboard 风格 Popover，服务器行保持 54pt 高度，并显示端点与当前选择状态。
- portable 后端下拉同步增加标题、54px 服务器行、更大的图标/圆角/间距和设置入口。
- 状态栏排版重做：运行状态保持独立单行，上传/下载速度作为右侧独立两行块，上下居中对齐；不再把 `Running/Stopped` 塞进速度两行文本。
- 保留 v1.0.3 的流畅度优化、设置 Tab、集中状态缓存，以及 v1.0.1 的 Core Secret 粘贴修复。

## v1.0.3

- 主界面新增“设置”Tab，可直接管理服务器、Core 路径、MetaCubeXD、Keychain Secret 与状态栏选项。
- 原生实时状态改为独立 `LiveStatusStore`，避免高频状态轮询让所有页面重复刷新。
- 主页面改成常驻视图栈，Tab 切换不再反复构建页面；订阅/日志改成按需延迟加载。
- 实时流量图改用异步 SwiftUI Canvas，降低布局与绘图成本。
- Keychain Secret 增加内存缓存，降低轮询路径上的系统调用。
- Portable runtime 增加共享 HTTP Client、Secret 缓存与集中式状态缓存；Web UI/状态栏复用本地缓存，移除状态栏定时 `curl` 子进程。
- Portable UI 取消页面切换动画和高成本模糊，在页面隐藏时暂停前端状态刷新。
- 状态栏上传/下载速度改为上下两行显示，并继续支持“显示运行状态 / 显示网速 / 仅显示图标”。

## v1.0.2

- 主窗口恢复为 Mihomo Core 管理面板 v4.0.0 同款 Dashboard UI：侧边栏、Core Hero、四项状态指标、实时流量图和快速控制。
- Core、订阅、日志、项目升级页面统一 Dashboard 视觉。
- 状态栏支持实时显示 Core 运行状态、上传速度和下载速度。
- 状态栏下拉菜单增加“显示运行状态”“显示网速”“仅显示图标”开关，并持久化选择。
- Portable arm64 版本同步实现状态栏实时轮询、多服务器切换与上述显示开关。
- 保留 v1.0.1 的 Core Secret `⌘V` / 显式粘贴修复。

## v1.0.1

- 修复 Core Secret 在即时安装版 WebKit 壳中无法使用 `⌘V` 粘贴的问题。
- 增加标准 macOS“编辑”菜单：撤销、剪切、复制、粘贴、全选。
- 原生与即时安装版的 Core Secret 输入均增加显式“粘贴”按钮。
- 主界面曾调整为低噪音 macOS 风格。
- 保持 Mihomo Core 管理面板 v4.0.0 API、Keychain、多服务器与自动 Release 兼容。

## v1.0.0

- 初始发布。
- Apple Silicon arm64 原生 macOS 客户端。
- 多服务器跨机管理、Bearer Core Secret、Keychain 凭据存储。
- 主窗口、状态栏菜单、订阅、日志、项目升级和自动签名/公证 Release。
