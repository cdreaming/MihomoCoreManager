- portable runtime 发布稳定性修复：统一跟踪异步缓存刷新，测试清理前等待后台任务；macOS 预检新增 100 次定向压力、全套 shuffle、Go race/vet 与 darwin/arm64 测试二进制交叉编译。
- 发布预检修复：macOS Swift semantic typecheck 显式绑定 Xcode macOS SDK 与 `arm64-apple-macos14.0` target，修复 Xcode 16.4 `unable to load standard library` 假失败。
- 发布预检再加固：`release-preflight.py --strict-macos` 自身先从精确 checkout 重建并验证源码 manifest，不再依赖前置 workflow 步骤；补齐 `BUILD-FIX-v1.2.4.md` 的清单覆盖。
- 发布流程修复：Release 在严格 macOS/Xcode 预检前从精确 tag checkout 刷新并验证 `SOURCE-SHA256SUMS.txt`；CI 仍保持 stale manifest 硬门禁，并增强差异诊断。
# Changelog

## v1.2.5

- 发布工程回归修复：恢复 v1.2.4 已验证的 Xcode 16.4 编译兼容规则（显式 Optional case、拆分大型 SwiftUI ViewBuilder、显式 Hashable、关闭 Swift batch mode），新增 `release-preflight.py` / `simulate-release.sh` 与 CI 失败日志上传，防止同类 `exit code 65` 回归。
- 状态栏下拉菜单上传/下载网速改为单行显示，减少菜单高度并保持实时刷新。
- 状态栏代理组区域增加前后分隔，代理组独立成组；portable 动态代理组插入位置固定在代理组结束分隔线之前。
- 原生 SwiftUI 状态栏面板同步将网速卡片收紧为单行，并在代理组前后增加分隔线。
- portable 主窗口标题栏/拖拽区由 52px 调整为 36px；原生窗口顶部安全间距由 38pt 调整为 26pt，约为原高度的 2/3。
- 标题栏底色改为与 Dashboard/侧栏一致的中性背景色；原生窗口暴露的 chrome backing 同步使用 Dashboard 深色背景。
- 版本升级为 v1.2.5 / build 125。

## v1.2.4

### v1.2.4 Hotfix

- Cloudflare Tunnel 稳定性修复：Controller GET 请求对 530/502/503/504 等临时网关错误做短重试；识别 Error 1033 并显示简短中文提示，不再把 Cloudflare 整段 JSON/HTML 直接抛给用户。代理页在临时断线时回退到最近一次成功快照，状态栏继续读取本地快照。
- 线路延时再次修正：按 MetaCubeXD 当前实现同时获取 `/proxies` 与 `/providers/proxies`，把 provider-only 具体节点补入节点表；组内成员若是嵌套策略组会递归解析到最终叶子节点。某个测试 URL 的 `delay=0` 不再覆盖其它 URL 已成功的正延时。
- 再修具体线路延时：Mihomo 当前 `extra` 实际结构为 `extra[testUrl] = { alive, history: [...] }`，不是直接 history 数组；原解析因此只能让部分代理组显示延时，具体线路读不到。原生 Swift 与 portable/Web/状态栏现已统一按真实结构解析。
- 修复“默认”代理组排序：不再使用 Mihomo `/group` 的 Go map 遍历结果，改用 `/proxies` 中 `GLOBAL.all` 提供的配置顺序；内置 `GLOBAL` 组放在配置组之后。
- 修复测速成功但代理线路不显示延时：统一读取显式组测速结果、`extra` URL 专属历史和 legacy `history`，显式测速结果优先。
- Web 代理页测速完成后直接把 `/group/{group}/delay` 返回值写回节点，不再依赖第二次远程刷新才能显示。
- 大幅优化 portable 状态栏：代理数据由 Go 后台轮询并原子写入本地快照，菜单打开/刷新不再发起 Controller 请求或启动 curl；代理组子菜单按需懒加载。
- 状态栏测速和线路切换改为异步队列，远端测速/PUT 不再阻塞 AppKit 菜单事件循环。
- 移除状态栏代理组前附加的 SF Symbol，保留组名自身的 emoji/旗帜。
- 状态栏代理线路同步显示最新显式测速或 Mihomo `extra/history` 延时。

- 代理组和代理列表新增默认、延时、质量、名字四种排序。
- 默认组排序读取 `/group` 的原始配置顺序；组内代理默认保持 `all` 顺序。
- 新增当前代理组测速，调用 `/group/{group}/delay`，只测试当前组。
- 测速结果按节点名共享，同一节点在其它代理组中同步显示最新测试延时。
- 状态栏新增顶层代理组菜单；每个组提供测速按钮和代理线路选择。
- portable 本地 bridge 新增 `/local/proxy-groups`、`/local/proxy-delay`，并缓存共享节点测速结果。
- 保留 v1.2.3 Controller Secret 独立认证修复。
- 版本升级为 v1.2.4 / build 124。

## v1.2.3

- 修复代理页错误复用管理面板 Core Secret 导致 Mihomo Controller 返回 HTTP 401 的问题；新增独立 Controller Secret，并在未设置时兼容回退 Core Secret。
- Controller Secret 与 Core Secret 分开保存到 macOS Keychain；Mihomo `secret: ''` 的无鉴权 Controller 也可正常访问。
- Controller HTTP 401 现在给出明确的 `config.yaml secret` 配置提示。
- 新增“代理切换”页面，连接 Mihomo Core Direct Controller API。
- 支持规则 / 全局 / 直连三种运行模式读取与切换。
- 展示代理组、当前代理、组内详细代理、类型、存活状态、最近延迟及 UDP / XUDP / TFO 能力。
- 支持 Selector / URLTest / Fallback 代理组直接切换节点。
- 原生 SwiftUI 与 portable arm64 版本同步实现；portable 新增 Controller API 回归测试。
- 版本升级为 v1.2.3 / build 123。

## v1.2.2

- 修复 v1.2.1 GitHub Release 在 portable 安装包阶段因 macOS Runner 未预装 Go 而报 `Go is required`、exit code 1 的问题。
- Release workflow 在 portable 构建前显式使用 `actions/setup-go@v6`，Go 版本直接读取 `portable-runtime/go.mod`，并增加 `CGO_ENABLED=0 go test ./...` 工具链 smoke test。
- macOS CI 同步配置 Go 并实际执行 `scripts/build-portable-installer.sh`，把 portable 发布路径前移到 PR/main 阶段回归。
- CI artifact 同时上传 `dist/` 与 `dist-portable/`。
- 保留 v1.2.1 正式 SwiftUI 状态栏 template image 修复和此前全部 UI/功能。
- 版本升级为 v1.2.2 / build 122。

## v1.2.1

- 修复 GitHub Actions/Xcode 正式版状态栏网速仍被 `MenuBarExtra` 压缩、只显示单个数字的问题。
- 原生 SwiftUI target 改为把上下行速率绘制进固定尺寸 template `NSImage` 后作为单一状态栏元素显示，彻底移除状态栏本体对多行 SwiftUI 文本布局的依赖。
- 保持上传在上、下载在下、靠下对齐、4 位等宽数字预留、左对齐、单位自适应及无箭头规则。
- GitHub Release workflow 同时构建 portable arm64 安装包，正式包与已验证 portable 包可在同一 Release 中直接对照。
- 版本升级为 v1.2.1 / build 121。

## v1.2.0

- 以 v1.1.9 为稳定基线，保留已确认的状态栏下拉面板，仅修复状态栏本体网速显示。
- portable 状态栏不再使用会被 macOS 单行 cell 裁切的 `NSStatusBarButton` 多行 title，改为按钮内独立 AppKit overlay 与上下两组原生文本标签。
- 上传在上、下载在下并整体靠下对齐；状态栏本体不再显示上下箭头。
- 速度数字左对齐并固定预留 4 个等宽字符位，单位独立显示并随速率自动切换。
- 原生 SwiftUI 状态栏同步采用左对齐四字符数字列与独立单位列。
- 继续避免 `NSButtonCell` 多行属性、`attributedTitle` 和 `CATextLayer` 高风险启动路径。
- 版本升级为 v1.2.0 / build 120。

## v1.1.9

- 以 v1.1.8 为基线，状态栏默认布局改为左侧应用图标、右侧上传/下载双行速率，上传在上、下载在下。
- 双行速率使用等宽数字并固定数值列右对齐，减少实时刷新时的横向跳动。
- 原生状态栏下拉由标准长菜单改为 `.window` 自定义紧凑面板，重新分组服务器、Core 操作、快捷入口、项目维护和显示选项。
- 原生状态栏运行状态改为图标状态点/精简文案，避免与网速争夺空间。
- portable 状态栏同步右对齐双行速率，并将长菜单折叠为分组子菜单、补充系统图标。
- 版本升级为 v1.1.9 / build 119。

## v1.1.8

- 保留 v1.1.7 已达标的异步按钮 busy 动画、忙碌鼠标指针和升级完成检测。
- 成功通知改为在按钮动作真正结束后自动收起，避免 `systemctl restart 完成` 等提示长期驻留。
- 左侧页面导航扩大整行点击范围，原生 47pt / portable 46px，并增加明显按下与回弹动画。
- 修复设置页首次进入仅显示服务器卡片、必须新增服务器后才显示完整选项的问题。
- 同步修复运行日志首次进入的持久页面加载任务 ID。
- 版本升级为 v1.1.8 / build 118。

## v1.1.7

- 项目升级按钮持续保持执行中状态，直到 `/api/project-update/log` 明确显示任务结束。
- 远端管理面板升级重启时继续轮询，避免按钮过早恢复。
- 原生异步操作按钮增加旋转进度指示与当前操作标识。
- portable UI 增加 busy class、`aria-busy`、全局 `cursor: progress`。
- 原生/Web 按钮按压缩放、位移、阴影反馈增强。
- 版本升级为 v1.1.7 / build 117。

## v1.1.6

- 修复 v1.1.5 按钮动画仍不符合预期的问题。
- `DashboardActionButtonStyle` 恢复为 v1.0.9 源码实现。
- 删除 `DashboardPressButtonStyle`、`0.08s easeOut` 与额外 disabled opacity。
- 侧栏、后端选择、Popover、文本链接、通知关闭按钮恢复 `.plain`。
- 保留 v1.1.5 的设置页排版与统一 UI。
- 版本升级为 v1.1.6 / build 116。

## v1.1.5

- 统一 Dashboard 按钮交互并参考 v1.0.9。
- 移除重复 Button 的 ViewThatFits 候选树。
- 设置页改为纵向；App 与状态栏改为双列分组。
- 概览/Core 成对卡片统一高度；日志页统一结构。
- 版本升级为 v1.1.5 / build 115。

## v1.1.4

- 修复 v1.1.3 Release 在 Xcode 16.4 下编译失败的问题。
- 修复 `OverviewView.swift` 非法 `.frame(width:minHeight:alignment:)` 调用，拆分为兼容的固定宽度与最小高度修饰器。
- 新增 SwiftUI `frame` 参数组合静态校验，避免同类错误进入 GitHub Actions 构建阶段。
- App 版本升级为 v1.1.4，Xcode build number 与 portable build number 统一为 114。
- 保留 v1.1.3 的统一布局修复、紧凑标题栏与 v1.0.9 菜单栏界面。

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
