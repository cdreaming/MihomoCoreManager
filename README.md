# Mihomo Core Manager for macOS

基于 **Mihomo Core 管理面板 v4.0.0** API 开发的 Apple Silicon（arm64）macOS 管理客户端。当前 App 版本为 **v1.2.12 (build 1212)**；`v4.0.0` 是服务端兼容基线，不是 App 版本。

## v1.2.12

v1.2.12 解决“本地/portable 验证正常，但 GitHub 原生 `.pkg` UI 又不同”的发布结构问题，并调整主窗口版本区：

- 主窗口左上版本信息固定为四行，顺序为 **本程序版本 / Core 版本 / Core 面板 / MetaCubeXD**。本程序版本读取 App bundle；Core 面板读取远端 `versions.management_panel`，两者不再混用。
- 正式 Release 改为 **One Canonical Native App**：Xcode Release 只编译一次，签名完成后冻结唯一 `MihomoCoreManager.app`；`.app.zip`、`native-installer.zip`、`.pkg` 全部只封装这一份 App。
- 新增 `NATIVE-APP-MANIFEST.json`：对冻结 App 内每个文件和符号链接生成确定性的 SHA-256 树清单。发布前会重新解包 `.zip`、native installer 和 `.pkg`，逐文件比较；任何差异都会让 GitHub Release 失败。
- 新增 `RELEASE-PROVENANCE.txt`，记录版本、build、Git commit、Xcode/Swift 版本、App tree SHA-256 与主二进制 SHA-256，Release 上传后还会在线下载全部资产再次验证。
- **portable-runtime 仍保留回归测试，但不再作为正式 GitHub Release 安装包发布。** 以后需要先验证 UI，请使用 GitHub 生成的 `arm64-native-installer.zip`；它与 `.pkg` 内是同一份原生 App，而不是另一套 UI 实现。
- 保留 v1.2.11 的状态栏背景色、隐藏滚动条、代理组当前线路刷新，以及此前窗口/状态栏稳定性修复。

## v1.2.11

v1.2.11 针对 GitHub/Xcode 原生 `.pkg` 中仍可复现的状态栏差异继续修正：

- 状态栏下拉窗口背景按提供的 macOS 网络面板参考图改为中性深灰 **#1A1A1D**，卡片使用 #1C1C21 / #201F23，避免偏蓝和过深。
- 超屏菜单保留滚轮/触控板纵向滚动，但通过 AppKit 直接关闭 `NSScrollView` 的 vertical scroller；不再依赖 SwiftUI `scrollIndicators(.hidden)`，GitHub Release 版也不会显示右侧粗拖动条。
- 代理组标题改为一个不可拆分的 `组名 · 当前线路` 文本，并在原生 MenuBarExtra 窗口每次成为 key 时刷新 Controller `now`；同时处理首次加载与菜单打开并发，避免只显示组名。
- 主窗口左上版本区将原“Core 面板 v4.0.0”改为“程序版本”，直接读取 App 自身 `CFBundleShortVersionString`；服务端 v4.0.0 只作为 API 兼容基线，不再冒充客户端版本。
- 保留 v1.2.10 的单图状态栏实时网速、v1.2.9 自适应菜单高度与 v1.2.8 窗口生命周期修复。

## v1.2.10

v1.2.10 继续针对 GitHub/Xcode 原生 `.pkg` 安装版统一状态栏与主窗口体验：

- 状态栏常驻标签改为**单一 AppKit 模板图像**渲染图标、运行状态与双行实时网速，绕过 `MenuBarExtra` 在 Release 构建中可能只保留首个图标的问题；“图标 / 状态 / 网速”开关会直接改变整张状态栏图像。
- 状态栏下拉菜单采用更柔和的深色背景；菜单超过一屏时仍可滚动，但隐藏系统纵向滚动条。
- 代理组当前选择改为与组名同一行的明确胶囊标签，并在每次打开状态栏菜单时重新读取 Controller `now`，避免 GitHub `.pkg` 版看不到已选线路或显示旧值。
- 主窗口右侧内容区改为略抬高的深灰蓝渐变背景，降低近纯黑大面积背景带来的压暗感，同时保留卡片层级对比。
- 保留 v1.2.9 自适应菜单高度以及 v1.2.8 窗口生命周期/恢复模式稳定性修复。

## v1.2.9

v1.2.9 修复 GitHub/Xcode `.pkg` 安装版状态栏窗口的高度策略：

- 状态栏下拉窗口不再强制显示为固定高度滚动框。
- 菜单内容能在当前屏幕完整显示时，按内容自然高度一次性全部展开，不显示多余滚动区域。
- 菜单内容超过当前屏幕可用高度时，才启用纵向滚动，可上下滑动访问全部项目。
- 高度上限跟随状态栏窗口所在显示器的 `visibleFrame`，切换屏幕或显示参数后会自动刷新。
- 保留 v1.2.8 的主窗口生命周期与状态栏恢复模式稳定性修复。

## v1.2.8

v1.2.8 以 v1.2.7 为稳定基线，集中修复 portable 安装版在“关闭主窗口 → 从状态栏重新打开”路径上的窗口生命周期与状态栏稳定性问题：

- App / Xcode / portable runtime 统一为 **v1.2.8 / build 128**。
- portable 主窗口显式关闭 `releasedWhenClosed`，主窗口关闭后保留原生 `NSWindow` 与 WebKit/拖拽视图，状态栏再次打开时不再访问已释放窗口对象。
- 每次从状态栏打开主窗口前重新确认 `movable` / `movableByWindowBackground`，保留顶部 22px 原生拖拽区，修复重新打开后窗口无法移动。
- 主状态栏 JXA shell 若发生一次瞬时退出，会先自动重启完整状态栏一次；连续失败才进入最小恢复模式，减少无必要的“状态栏渲染已降级”。
- 初次构建服务器/代理菜单与状态刷新增加 fail-soft 保护，损坏或暂时不完整的本地快照不会带退出整个状态栏进程。
- 恢复模式窗口也改为保留窗口对象并加入原生拖拽区；即使真正进入恢复模式，主窗口仍可正常移动和再次打开。

## v1.2.7

v1.2.7 以本次 `source-4` 功能代码为基线，并重新套用已经成功发布的 **v1.2.5 fixed5 发布工程设置**。业务层保留 source-4 的流畅度、状态缓存、代理菜单即时刷新和完整左右布局；发布层恢复经过 v1.2.4 / v1.2.5 实际发布验证的完整硬门禁。

- App / Xcode / portable runtime 统一为 **v1.2.7 / build 127**。
- CI 与 Release 都只调用 `scripts/simulate-release.sh`，避免两套发布流程漂移。
- strict macOS preflight 自行重建/复核 manifest，并使用当前 Xcode macOS SDK + `arm64-apple-macos14.0` 做 semantic typecheck。
- Release Xcode build 固定 `SWIFT_ENABLE_BATCH_MODE=NO`，保存完整 `xcodebuild-release.log` 并在失败时回显真实编译错误。
- 恢复 v1.2.4 Xcode 16.4 兼容写法：显式 Optional switch、独立 `ProxySortPicker`、拆分大型 SwiftUI result builder、显式 `Hashable`、具体 history 中间类型和 macOS 14 双参数 `onChange`。
- portable 异步缓存/状态刷新重新纳入 `backgroundWG + goBackground()` 生命周期；TempDir 测试清理前等待后台任务，避免 macOS/APFS `directory not empty` 竞态。
- 发布模拟包含目标竞态重复测试、shuffle、race、vet、Darwin/arm64 runtime/test binary 交叉编译、portable ZIP/Mach-O/版本校验；真实 `macos-15` arm64 Runner 继续执行 Xcode Release build 和最终 SHA-256 回放。
- `SOURCE-SHA256SUMS.txt` 按最终源码重新生成。

## v1.2.5

v1.2.5 以 v1.2.4 的代理排序、测速、Cloudflare 容错和状态栏性能修复为稳定基线，继续优化状态栏代理切换刷新和主窗口布局：

- 状态栏下拉菜单中的上传/下载实时网速保持**同一行**显示；代理组区域继续使用前后分隔线独立成组。
- 修复从状态栏重新选择线路/代理组后，顶层代理组后缀仍停留在旧线路的问题：成功选择后立即更新本地菜单快照和可见菜单标题，再延迟同步 Controller 权威状态。
- 原生 SwiftUI 同步避免成功 PUT 后首次旧 `now` 响应覆盖新选择，并让代理组菜单 identity 包含当前选中项，确保后缀和勾选立即刷新。
- 主窗口重构为完整的**左侧导航 + 右侧内容**布局，去掉独立视觉标题栏；portable 仅保留 22px 不可见原生拖拽区域，原生 SwiftUI 使用 `hiddenTitleBar + fullSizeContentView`。
- 左侧标题区采用蓝紫 `M` 图标 + 两行 `Mihomo Core / 管理面板`；标题改用与界面一致的系统字体和主文字色（深色界面呈柔和白色），版本信息置于其下，并移除重复的独立 `Mihomo Core` 标题。
- 侧栏统一为 256pt/px，标题字重、间距、主文字色与深色背景按 Dashboard 风格统一。
- 版本保持 v1.2.5 / build 125。

## v1.2.4

**v1.2.4 Cloudflare 容错修订**：Controller 经 Cloudflare Tunnel 暴露时，HTTP 530 / Error 1033 会自动短重试；仍不可达时，代理页和状态栏继续使用最近一次成功的代理/延时快照，并显示简短断线提示，不再输出整段 Cloudflare JSON/HTML。

**v1.2.4 修订版**：修复默认代理组顺序、线路延时显示和状态栏菜单卡顿。默认组顺序现在以 `GLOBAL.all` 的配置顺序为准；测速结果会直接回填并兼容 Mihomo `extra/history`；portable 状态栏使用本地原子快照 + 懒加载子菜单，打开菜单不再等待远程 Controller。 线路延时数据同时合并 Mihomo `/providers/proxies`，确保 provider-only 具体节点也进入节点表；嵌套策略组会递归解析到最终叶子节点，并复用其它 Test URL 已成功的正延时。

v1.2.4 基于已经验证 Controller 连接正常的 v1.2.3 继续增强代理管理体验：

- “代理组”和“代理列表”分别支持 **默认 / 延时 / 质量 / 名字** 四种排序。
- 默认排序：代理组优先使用 Mihomo `/group` 返回的配置顺序，代理列表保持组内 `all` 原始顺序。
- 延时排序：按最近一次显式测速结果优先，其次使用 Mihomo 历史延时，未知/超时结果靠后。
- 质量排序：综合节点存活状态、近期失败次数、延时抖动、平均延时和最新延时，优先显示稳定线路。
- 代理详情增加“测速当前组”，使用 Mihomo `GET /group/{group}/delay`，只测试当前组。
- 当前组测速结果按节点名全局共享：同一个节点同时出现在其它代理组时，其它组会立即显示相同测速结果。
- 状态栏新增代理组顶层入口：每个代理组都可直接测速，并可在子菜单中切换该组代理线路。
- 原生 SwiftUI 与 portable arm64 安装版同步实现。
- 版本升级为 v1.2.4 / build 124。

## v1.2.3

- **认证修复**：Controller Secret 与原 Core Secret 分离，分别保存到 Keychain；未配置 Controller Secret 时兼容复用 Core Secret，并支持 Mihomo `secret: ''`。
v1.2.3 在 v1.2.2 稳定发布基线上新增 Mihomo Core 代理切换能力：

- 新增侧栏“代理切换”页，直接连接当前服务器配置的 **Direct Core Controller URL**，使用同一份 Core Secret 进行 Bearer 鉴权。
- 新增运行模式切换：**规则（rule）/ 全局（global）/ 直连（direct）**。
- 读取并展示代理组、当前选中代理与组内详细代理；支持代理名称筛选。
- 详细代理展示类型、存活状态、最近延迟以及 UDP / XUDP / TFO 能力信息。
- 支持 Selector / URLTest / Fallback 类型代理组的节点切换，并在切换后自动刷新当前选择。
- 原生 SwiftUI 与 portable arm64 安装版同步实现；portable 增加 Controller 模式、代理读取和代理选择回归测试。
- 版本升级为 v1.2.3 / build 123。

### v1.2.3 Direct Core Controller API

| 功能 | Mihomo Core API | 客户端行为 |
| --- | --- | --- |
| 读取运行模式 | `GET /configs` | 读取 `mode` |
| 切换运行模式 | `PATCH /configs` | 写入 `rule` / `global` / `direct` |
| 读取代理 | `GET /proxies` | 展示代理组与详细代理 |
| 切换代理 | `PUT /proxies/{group}` | 写入目标代理 `name` |

## v1.2.2

v1.2.2 是 v1.2.1 的 GitHub Actions 构建热修复，状态栏显示逻辑保持 v1.2.1 不变：

- 修复 Release 在执行 `scripts/build-portable-installer.sh` 时因 macOS Runner 未预装 Go 而报 `Go is required`、exit code 1 的问题。
- `.github/workflows/release.yml` 在 portable 测试/构建前显式使用 `actions/setup-go@v6`，Go 版本由 `portable-runtime/go.mod` 提供。
- Release 增加 `go version` 与 `CGO_ENABLED=0 go test ./...` smoke test，让 Go 工具链问题在正式发布构建前立即暴露。
- `.github/workflows/ci.yml` 同步安装 Go，并执行同一个 `scripts/build-portable-installer.sh`，以后 PR/main CI 就能覆盖 portable 发布路径。
- CI artifact 同时包含 `dist/` 与 `dist-portable/`；v1.2.1 的正式 SwiftUI 状态栏 template image 修复、v1.1.9 下拉面板及 portable/AppKit 行为全部保留。

## v1.2.1

v1.2.1 是针对 GitHub Actions 正式 Xcode/SwiftUI 构建的状态栏热修复；portable/AppKit v1.2.0 已验证正常的行为保持不变：

- 修复正式 SwiftUI `MenuBarExtra` 直接承载双行 `VStack` 时被 macOS 状态栏压缩为单行，导致 GitHub 自动构建版只显示单个数字/单位缺失的问题。
- 正式版把上传/下载两行速率预渲染为一个固定 55×18pt 的 template `NSImage`，再作为单一状态栏元素交给 `MenuBarExtra`，避免系统重新排版内部两行文本。
- 上传在上、下载在下；数字左对齐并固定预留 4 个等宽字符位，单位独立列自动切换 `B/s / KB/s / MB/s / GB/s / TB/s`，状态栏本体仍不显示箭头。
- v1.1.9 自定义下拉面板以及 v1.2.0 portable/AppKit 双行状态栏实现均保持不变。
- GitHub Release workflow 现在同时构建并发布正式 SwiftUI `.pkg/.zip` 与已验证的 portable arm64 安装包，便于直接回归对比。

## v1.2.0

v1.2.0 以 v1.1.9 为基线，只修复状态栏本体的实时网速显示，保留已经达标的自定义下拉面板：

- 修复 portable 安装版依赖 `NSStatusBarButton` 多行 title 导致网速在状态栏本体被系统裁切/不显示的问题。
- portable 改为在状态栏按钮内放置可将点击转交给状态栏按钮的原生 AppKit overlay，上传与下载由两组独立 `NSTextField` 渲染，不再依赖多行 title，也不恢复高风险的 `NSButtonCell` 多行属性、`attributedTitle` 或 `CATextLayer`。
- 上传固定在上半行、下载固定在下半行，整个双行速度块向状态栏底部对齐。
- 速度文本只显示数字与自动切换的 `B/s / KB/s / MB/s / GB/s / TB/s` 单位，不显示上传/下载箭头。
- 数字区域预留 4 个等宽字符位并左对齐，单位使用独立列；实时数值变化和单位切换时两行左边缘保持稳定。
- 原生 SwiftUI `MenuBarExtra` 标签同步使用相同的双行、左对齐、4 字符数字位规则。
- v1.1.9 的紧凑自定义下拉面板与其它按钮/页面修复全部保持不变。

## v1.1.9

v1.1.9 以 v1.1.8 为基线，集中重做 macOS 状态栏显示与下拉菜单体验：

- 状态栏默认组合显示改为“应用图标在左 + 上传/下载双行网速在右”；上传在上、下载在下，数值使用等宽数字并右对齐，流量变化时不会左右跳动。
- 运行状态在显示图标时改为图标右下角的小状态点，不再和双行网速争抢横向空间；关闭图标或网速时仍保留对应状态文案。
- 原生 `MenuBarExtra` 从标准长菜单升级为 `.window` 自定义面板：增加品牌/版本/状态头部、实时上下行卡片、当前服务器卡片、Core 快捷控制、常用入口、项目维护与状态栏显示开关。
- 下拉面板操作按钮统一使用更明显的按压/回弹反馈，并直接映射当前异步操作的 busy 状态。
- portable arm64 状态栏同步修复上传/下载顺序、右对齐与固定宽度；下拉菜单改为紧凑的“服务器 / Core 控制 / 管理与工具 / 状态栏显示”分组子菜单，并补充 SF Symbols 图标。
- 保留 v1.1.8 的通知自动收起、侧栏命中区域修复和设置页首次加载修复。

## v1.1.8

v1.1.8 以 v1.1.7 按钮动画为基线，修复日常交互中的四个体验问题：

- 成功通知自动收起：按钮操作产生的成功提示会在操作真正结束、按钮退出 busy 状态后自动消失；错误提示仍保留供排查。
- 左侧页面导航整行可点击，原生行高提升为 47pt，增加缩放、下沉、亮度与 spring 回弹；portable UI 同步扩大命中区域。
- 修复“设置”持久页面首次打开不加载当前服务器草稿的问题，无需再新增服务器即可看到“服务器连接 / Core 配置 / App 与状态栏 / 保存设置”等完整选项。
- 同步修复运行日志首次切换时的加载任务 ID。
- 完整保留 v1.1.7 的当前操作 spinner、旋转 busy cursor 和项目升级完成检测。

## v1.1.7

v1.1.7 优化异步操作按钮的完整执行反馈：

- “开始项目升级”不再在远端仅返回“已启动”后立即恢复；持续读取升级日志的 `running` 状态，确认任务结束后才恢复初始按钮。
- 升级 Core 管理面板导致远端短暂重启/断连时保持“项目升级中…”状态并继续检测，避免误判失败或提前结束动画。
- 原生 SwiftUI 为当前执行按钮显示 `ProgressView`；鼠标停留在执行中按钮时切换为旋转 busy cursor，开启“减少动态效果”时自动使用静态指针。其它操作保持禁用，完成/失败后统一由 `defer` 恢复。
- portable Web UI 为执行中按钮增加 spinner、`aria-busy` 和全局 `cursor: progress` 忙碌指针反馈。
- 按压效果增强：原生按钮按下缩放到 `0.955` 并加入位移/阴影反馈；Web 按钮缩放到 `0.945` 并增加高亮闪层与内阴影。
- 保留 `prefers-reduced-motion` / macOS Reduce Motion 兼容。

## v1.1.6

v1.1.6 再次修复按钮交互，直接恢复 v1.0.9 的实现：

- `DashboardActionButtonStyle` 与 v1.0.9 源码实现一致。
- 删除 v1.1.5 新增的 `DashboardPressButtonStyle`。
- 删除显式 `0.08s easeOut` 和额外 disabled opacity 动画。
- 侧栏、管理后端、Popover、文本链接、通知关闭按钮恢复 v1.0.9 的 `.plain` 行为。
- 主操作按钮保留 v1.0.9 的按下背景反馈与 `0.985` 缩放。
- v1.1.5 的设置页纵向结构、双列“App 与状态栏”和统一页面 UI 全部保留。

## v1.1.5

- 全量统一按钮按压反馈，参考 v1.0.9 的背景变化与 `0.985` 缩放，并补充稳定的 0.08 秒回弹。
- 移除会复制 Button 子树的 `ViewThatFits`。
- 设置页纵向排列；“App 与状态栏”改为双列分组。
- 概览和 Core 成对卡片统一高度；日志页统一页面结构。

## v1.1.4

这是 v1.1.3 统一布局版的构建修复版本，正式版本升级为 **v1.1.4 (build 114)**。

- 修复 `OverviewView.swift` 中 SwiftUI `frame` 参数组合导致的 Xcode 16.4 编译失败。
- 将固定宽度与最小高度拆分为两个合法的 `frame` 修饰器，保持“实时流量 / 快速控制”布局设计不变。
- 增加源码校验规则，提前拦截固定 `width/height` 与 `min/max/ideal` 尺寸混用的非法 `frame` 调用。
- 保留 v1.1.3 的统一页面布局、紧凑标题栏和 v1.0.9 菜单栏样式。

## v1.1.3

本版本基于已完成界面统一修复的 v1.1.2 源码发布，版本升级为 **v1.1.3 (build 113)**。

- 保留 v1.1.2 的紧凑标题栏优化。
- 保留“概览 / Core 控制 / 订阅管理 / 设置”等页面的统一布局修复。
- 保留 v1.0.9 风格的原生菜单栏标签界面。
- 不改变 Mihomo Core API、订阅处理、升级流程和 portable runtime 功能逻辑。

## v1.1.2

这一版在保留 v1.1.1 功能的基础上，修复界面并压缩主窗口顶部占用：

- **菜单栏恢复 v1.0.9 风格**：恢复原有布局、字号、间距、`Running / Stopped / Checking` 文案与 `↓ / ↑` 双行网速显示。
- **紧凑标题栏**：主窗口使用隐藏标题栏底板的原生窗口样式，让 Dashboard 延伸到顶部，减少空白和无效高度。
- **保留系统窗口按钮**：红黄绿按钮仍使用 macOS 原生控件，不做缩放或自绘。
- **避免顶部重叠**：左侧品牌区为窗口按钮保留紧凑安全区，不重新制造厚标题栏。
- **功能保持 v1.1.1**：管理后端选择器、窗口拖拽、性能优化、portable runtime 和 unsigned Release 流程全部保留。

## v1.1.1

这一版集中修复原生状态栏显示问题：

- **更紧凑的状态栏宽度**：收紧 `MenuBarExtra` 标签横向间距，减少左右空白占用。
- **更好的垂直居中**：统一状态栏标签高度，修复图标、状态文本和双行网速在菜单栏内上下不居中的问题。
- **更稳定的双行网速排版**：上传/下载箭头改用 SF Symbols，并优化两行间距与对齐。
- **更短的状态文案**：显示 `On / Off / Wait`，减少状态栏横向长度。
- 继续保留 v1.1.0 的无需 Apple Developer Secrets 的 Release 自动构建流程。

## v1.1.0

这一版主要修复 GitHub Actions 自动 Release 在没有 Apple Developer 凭据时直接失败的问题：

- **Release 默认无需 Apple Secrets**：移除 Developer ID / Notary Secrets 强制校验和证书导入步骤。
- **自动构建未签名 Release**：GitHub Actions 默认使用 `scripts/build-release.sh --unsigned`，继续生成 arm64 `.zip`、`.pkg`、Release Notes 和 SHA-256 清单。
- **保留自动发布**：支持 tag `v1.1.0` 和手工 `workflow_dispatch`，并自动创建/更新 GitHub Release、上传资产、在线回读验证 SHA-256。
- **保留正式签名能力**：`scripts/build-release.sh --signed` 路径未删除，以后有 Apple Developer 证书时仍可重新启用签名与公证。
- **安装提示**：默认产物没有 Developer ID / Apple Notary 身份，其它 Mac 首次安装/启动时可能出现 Gatekeeper 提示。
- 保留 v1.0.9 的状态栏组合显示、订阅热重载超时安全恢复及此前全部功能。

## v1.0.9

这一版集中修复状态栏组合显示与订阅“保存并应用”超时问题：

- **图标 / 网速 / 运行状态可同时显示**：三项改为独立开关；状态栏仍使用紧凑双行网速（下载在上、上传在下），图标与运行状态可以同时保留。
- **升级兼容**：旧版设置没有 `showIcon` 字段时自动按“显示图标”迁移，避免升级后图标意外消失；若三项被全部关闭，会自动保留图标以确保菜单仍可点击。
- **订阅热重载超时自动恢复**：Mihomo Core 管理面板 v4.0.0 会把保存、renderer 校验和热重载放在一个事务里，热重载超时会回滚配置。v1.0.9 仅在确认是“热重载超时且已回滚”时自动切换为一次安全重启流程：停止 Core → 再次保存并校验 → 启动 Core。
- **避免误重启**：URL 非法、renderer 失败、配置校验失败等其它错误不会触发安全重启，仍按原错误返回。
- 保留 v1.0.8 的等宽“管理后端”下拉、v1.0.7 的菜单栏崩溃保护/Recovery Shell、Core Secret 粘贴、窗口拖动与集中状态缓存。

## 功能范围

1. **Apple Silicon arm64 原生应用**：Xcode 工程固定 `ARCHS=arm64`，最低 macOS 14.0。
2. **跨域 / 跨机管理**：正式 SwiftUI App 使用原生 `URLSession`，不受浏览器 CORS 限制；支持多服务器 Profile、域名、内网 IP 与 VPN 地址。
3. **配置设置**：每台服务器可设置 Management URL、Core Secret、Direct Core Controller URL、远端 `config.yaml` 路径、MetaCubeXD URL、HTTP 兼容和升级保留策略。
4. **状态栏管理**：图标、运行状态、实时网速三项可独立开关并同时显示，菜单覆盖日常管理动作。
5. **自动发布**：GitHub Actions 在 macOS arm64 Runner 构建；v1.1.0 默认无需 Apple Developer Secrets，自动生成未签名 `.pkg` / ad-hoc 签名 App ZIP 并发布到 GitHub Release。

## v4.0.0 API 兼容

| 功能 | API |
| --- | --- |
| 状态 / 流量 / 版本 | `GET /api/status` |
| Core 启停 / 重启 / 热重载 | `POST /api/action` |
| 订阅读取 / 保存应用 | `GET/POST /api/subscriptions` |
| 运行日志 | `GET /api/logs?lines=N` |
| 项目更新检查 | `GET /api/project-update/check` |
| 项目更新执行 | `POST /api/project-update/apply` |
| 更新日志 | `GET /api/project-update/log` |

认证使用 `Authorization: Bearer <Core Secret>`。Secret 不写入 Profile 文件，正式 App 使用 macOS Keychain；portable runtime 使用 `/usr/bin/security` 访问同一 Keychain service。

## 本地构建

要求：Apple Silicon Mac + Xcode（macOS 14 SDK 或更高）。

```bash
python3 scripts/validate-source.py
python3 scripts/build-source-manifest.py --check
xcodebuild \
  -project MihomoCoreManager.xcodeproj \
  -scheme MihomoCoreManager \
  -configuration Debug \
  -destination 'platform=macOS' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  build
```

## Release

正式 tag `v1.2.2` 成功后生成：

```text
MihomoCoreManager-v1.2.2-arm64.pkg
MihomoCoreManager-v1.2.2-arm64.zip
MihomoCoreManager-v1.2.2-arm64-portable-installer.zip
release_v1.2.2_notes_zh-CN.md
SHA256SUMS.txt
```

v1.1.0 默认 Release **不需要 Apple Developer Repository Secrets**。默认产物没有 Developer ID / Apple Notary 身份；若以后需要正式签名与公证，可继续使用保留的 `scripts/build-release.sh --signed` 路径并重新接入 Apple 凭据。

## 当前非 macOS 构建环境的交付说明

`portable-runtime/` 可在 Linux 上交叉编译为 `darwin/arm64` Mach-O，并在 macOS 上通过系统 AppKit/WebKit + JXA 提供主窗口与状态栏菜单，用于即时安装/测试。GitHub Release 仍以 Xcode/SwiftUI 目标为准；v1.1.0 默认走无需 Apple 凭据的未签名发布路径。
