# Changelog

## v1.3.5

- 状态栏下拉菜单头部重新排版：BrandLogo 放大并固定在左侧跨两行，右侧第一行显示 Mihomo Core / Core 版本 / 运行状态，第二行显示上传与下载实时网速。
- SwiftUI 使用 46pt BrandLogo；GoWebUI AppKit/JXA 使用 44pt 彩色 BrandLogo + 58pt 自定义菜单头部，保持两套实现的信息结构与视觉占位一致。
- 保留 v1.3.4 的状态栏常驻逻辑：关闭主窗口不退出状态栏，只有从状态栏执行“退出 MihomoManager”才终止程序。
- App / Xcode / GoWebUI runtime 统一升级为 v1.3.5 / build 1305。

## v1.3.4

- 状态栏下拉菜单头部二次调整：LOGO 放大并固定在左侧跨两行；右侧第一行显示 Core/版本/运行状态，第二行显示上传/下载网速。GoWebUI 使用 44pt 彩色 LOGO，SwiftUI 使用 46pt BrandLogo，保持同一双行信息结构。

- SwiftUI 与 GoWebUI 状态栏下拉菜单顶部图标统一改为 MihomoManager BrandLogo/AppIcon 128px 同源 LOGO。
- 状态栏常驻图标由 `circle.grid.cross` 改为 LOGO；布局统一为 LOGO 靠左、运行状态点居中、双行实时网速靠右。
- SwiftUI 增加 `applicationShouldTerminateAfterLastWindowClosed = false`；GoWebUI 主 JXA 壳与恢复壳同步保持最后窗口关闭后继续常驻。
- 状态栏“退出 MihomoManager”继续作为完整退出入口，GoWebUI 会先通知本地 runtime 关闭再终止 AppKit。
- GoWebUI App Bundle 新增 `Contents/Resources/BrandLogo.png`，由共享 AppIcon-128 直接写入，保证与 SwiftUI BrandLogo 视觉源一致。
- App / Xcode / GoWebUI runtime 统一升级为 v1.3.4 / build 1304。

## v1.3.3

- SwiftUI 主窗口左下角后端状态文案与 GoWebUI 统一为“后端已连接 · <manager>”/“后端未连接 · 检查设置”。
- Core 控制页“服务控制”优先级说明改为四行结构化排版，并将 GoWebUI 原有的旧 systemd 优先文案同步修正为 v1.3.2 以来的 API-first / explicit-SSH 策略。
- 根目录 README 新增 `HomePage.png` 与 `CorePage.png` 两张界面截图。
- App / Xcode / GoWebUI runtime 统一升级为 v1.3.3 / build 1303。

## v1.3.2
- Portable recovery 打包修复：legacy Go 补写 `LC_UUID` 后同步刷新 Mach-O ad-hoc CodeDirectory 哈希；安装脚本不再吞掉 `codesign` 失败，并清理 quarantine 后执行严格签名校验。

- 修复 GoWebUI 在 macOS 15+ App Bundle 中访问局域网 Controller / Core 服务面板 / MetaCubeXD 时可能出现 `No route to host` 的打包根因：正式工具链升级为 Go 1.26.8，移除 `-buildid=`，并将非零 Mach-O `LC_UUID` 设为发布硬门禁。
- SwiftUI / GoWebUI `Info.plist` 均增加 `NSLocalNetworkUsageDescription`。
- 修复 v1.3.1 GoWebUI Management Secret Keychain service 与 SwiftUI 不一致：统一到 `cc.kkr.MihomoManager.profile-secret`，兼容迁移错误/旧 service，保存后回读校验。
- SSH 从自动推断主机改为显式 opt-in；不再因为局域网 TCP 失败自动用当前 macOS 用户名连接服务器。
- 服务控制优先级统一为 Controller（适用操作）→ Core 服务面板 Management API → 显式 SSH/systemd 最终回退；运行日志优先面板 `/api/logs`，再到显式 SSH `journalctl`。
- GoWebUI 右下角 `GoWebUI · Remote` 改为本机 UI/后端连接状态文案，避免误判为端口冲突。
- App / Xcode / GoWebUI runtime 统一升级为 v1.3.2 / build 1302。

## v1.3.1

- **修复侧栏三组件版本：** Controller 快速状态成功时不再丢失 Management 元数据；SwiftUI/GoWebUI 均从 v4.0.1 `/api/status` 补齐 `management_panel` / `metacubexd` 版本，Core 版本继续以 Controller `/version` 为权威，项目升级后主动失效版本缓存。
- **修复 Core 控制页卡片溢出：** SwiftUI 删除“服务控制 / 服务信息”外层固定 300pt 高度，改为顶部对齐、统一最小高度并允许右侧信息卡向下自然增长。
- **接口三层逻辑统一：** runtime 为 Controller → systemd → Management；Controller/Management 传输为直连 → SSH 原 URL → SSH `127.0.0.1` 同 scheme/port/path；systemd SSH host 为显式 target → LAN Management → LAN Controller。
- **URL 规范化增强：** `/ui/` / `/Ui/` 与已知 Controller/Management API 尾部可直接粘贴，反代前置路径/显式端口保留；省略 scheme 按 LAN→HTTP / 公网→HTTPS；拒绝 `0.0.0.0` / `::` 作为客户端目标，不猜 9090/29090/29091。
- **systemd 对齐 v4.0.1：** reload 先检查 `CanReload`，默认 unit 无 `ExecReload` 时跳过无效 `systemctl reload` 并进入面板 fallback；start/restart 直控前 best-effort disable unit，保持服务器原来的 no-autostart 策略。
- **MetaCubeXD LAN-first：** 显式 LAN URL → LAN Management host + 面板报告 standalone port → 显式/状态公网 URL；GoWebUI 提示与实际打开地址使用同一 resolver。

- **对照 mihomo-web-installer v4.0.1 的同版本接口修订：** SwiftUI 与 GoWebUI 统一为 Controller/Management **直连 → SSH 原地址 → SSH 127.0.0.1 同端口**传输链；Controller `/ui/` / `/Ui/` 规范化保留反代前置路径，Management 已知 `/api/*` 后缀可回收到根地址，所有显式端口原样保留且不自动猜 9090/29090/29091。
- **结果逻辑修订：** Controller 主状态路径从 `/connections` 累计流量差分补算瞬时上传/下载速度，避免主路径成功时菜单栏显示 0 B/s；systemd 日志改用 `journalctl ... -o short-iso` 与参考部署一致保留时间戳。
- **程序名统一为 MihomoManager：** App bundle、可执行文件、菜单/通知、portable 安装/卸载脚本及 v1.3.1 产物统一新名称；旧 `MihomoCoreManager` Application Support / Keychain 数据自动兼容读取并迁移。
- 同版本 GoWebUI 网络 hotfix：Controller/Management 端口直连出现 `no route to host`、拒绝连接、超时或临时网关故障时，自动通过服务器 SSH 重试同一 API；服务器访问原 URL 仍失败时，保留原 scheme/port/path 并改试 `127.0.0.1`。覆盖运行日志、订阅管理、代理读取/切换/测速、项目更新等路径，不新增或猜测 9090/29090。LAN Profile 的 SSH 目标留空时可从 Management/Controller URL 自动推断主机；公共域名不会自动探测 SSH。
- 同版本 CI 修复：GitHub Actions 自动构建改用 `macos-15-intel` 交叉产出 arm64-only 双实现安装包，避免标准 Apple Silicon runner 排队卡住。

- **同版本 hotfix（仍为 v1.3.1 / build 1301）：** 主窗口左侧后端选择标签由“服务器”修正为“后端管理”，其余导航标签保持 v1.3.1 不变。
- 巡查远端接口并优先采用 Mihomo Controller API：重启 Core 改为优先 `POST /restart`，失败时保留管理面板兼容回退；状态、配置、代理、测速、切换继续直接走 Core API。
- “服务设置”按 v1.3.0 设置能力补齐：GoWebUI 恢复状态刷新间隔与默认日志行数，补 Management Secret 清除；SwiftUI/GoWebUI 恢复 Controller Secret 留空复用 Management Secret 的兼容说明。

- 主窗口右侧内容顶部统一下移并与左侧品牌区 38pt/px 顶线对齐；SwiftUI/GoWebUI 同步优化顶部与底部留白。
- 导航“设置”Tab 与页面标题统一改为“服务设置”，相关配置提示同步调整。
- 使用用户提供的 `MihomoCoreManager-2.png` 作为唯一图标源，重新生成 SwiftUI Xcode AppIcon、GoWebUI 内嵌界面图标与 `.icns` 输入。
- 修复 GoWebUI 访问局域网后端时可能受环境代理影响的问题：私网、loopback、link-local、Bonjour `.local`、`.lan`、`.home.arpa` 和单标签主机强制直连。
- GoWebUI macOS/CGO=0 增加系统主机解析回退，改善局域网主机名与 mDNS/Bonjour 连接。
- Cloudflare Tunnel 稳定性加强：安全 GET/HEAD 失败采用退避重试，瞬时网关故障后清理空闲连接，状态/代理后台轮询连续失败自动降低频率，并保留最近成功代理快照。
- SwiftUI 状态轮询连续失败时指数退避，管理 API 与 Controller 统一解析 Cloudflare 530 / Error 1033，减少恢复期请求风暴。
- App / Xcode / GoWebUI runtime 统一升级为 v1.3.1 / build 1301。

## v1.3.0

- 全新现代化 AppIcon：蓝青/蓝紫渐变、抽象 M 网络路径 + 连接节点，16–1024px 全尺寸共享给 GoWebUI 与 SwiftUI。
- 固定开发交付为“源码 + GoWebUI portable”，不再等待额外发布确认。
- GitHub Release 同版本并行生成 `GoWebUI-arm64.pkg` 与 `SwiftUI-arm64.pkg`，文件名明确区分两套实现。
- GoWebUI portable 与 GitHub GoWebUI.pkg 强制共用 `scripts/build-gowebui-app.sh`，避免预览版与 GitHub Go 版出现第二套 UI 构建逻辑。
- 新增独立 `BUILD_NUMBER=1300`，避免 1.3.0 使用点号删除法得到 130 而导致 build 倒退。
- 新增可固化到 AI 项目开发模板的双 macOS 构建规则文档。

## v1.2.12

- 主窗口左上版本区调整为 `本程序版本 / Core 版本 / Core 面板 / MetaCubeXD` 四行；App 版本与远端 Core 面板版本分别显示，不再互相替代。
- 正式 Release 引入 One Canonical Native App 契约：Xcode Release 只生成并冻结一份原生 `MihomoCoreManager.app`，`.app.zip`、`arm64-native-installer.zip` 与 `.pkg` 全部从同一冻结 App 打包。
- 新增 `NATIVE-APP-MANIFEST.json` 和 `scripts/verify-native-release-parity.sh`，发布前/发布后均重新解包三种正式容器并逐文件 SHA-256 比对；App bundle 任意字节差异都会阻止发布。
- 新增 `RELEASE-PROVENANCE.txt`，记录 source commit、Xcode/Swift、App tree hash 和 executable hash，GitHub Release 在线回读时复核 commit 与所有资产校验和。
- portable Go/AppKit/Web 版本降级为 **回归测试专用**，不再上传为正式 GitHub Release 安装包，避免用户把两套 UI 实现误认为同一个构建。
- 正式新增 `MihomoCoreManager-v1.2.12-arm64-native-installer.zip`；它包含与 `.pkg` 完全相同的原生 App，可用于安装前 UI 验收。
- App / Xcode / portable regression runtime 统一为 v1.2.12 / build 1212。

## v1.2.11

- 状态栏下拉菜单根背景改为参考图中性深灰 #1A1A1D，并增加独立 menu surface palette，避免 GitHub/Xcode `.pkg` 继续使用偏蓝近黑背景。
- 超屏状态栏菜单由 AppKit `NSScrollView` 层显式 `hasVerticalScroller=false`，彻底隐藏右侧系统拖动条，同时保留滚轮、触控板与键盘滚动能力。
- 代理组根标题固定为一个 `组名 · 当前线路` Text，避免 Release `Menu` 丢弃自定义 label 的次要子视图；菜单窗口每次呈现时重新刷新 Controller `now`，并等待冲突中的首次代理加载。
- 主窗口左上“Core 面板：v4.0.0”替换为“程序版本：v1.2.11”，版本从 App bundle 的 `CFBundleShortVersionString` 读取。
- App / Xcode / portable runtime 统一为 v1.2.11 / build 1211。

## v1.2.10

- 修复 GitHub/Xcode `.pkg` 状态栏常驻区只显示图标的问题：图标、Running/Stopped 与双行实时网速统一渲染成一个可变宽 AppKit template image，避免 `MenuBarExtra` Release 标签裁剪。
- 状态栏显示开关继续使用原有 UserDefaults，但切换后会强制刷新完整单图标签，避免看起来“开关失效”。
- 下拉菜单背景调亮并保留深色层级；超屏时隐藏系统粗滚动条，触控板/鼠标滚轮滚动不受影响。
- 代理组把当前 `now` 线路直接显示在组名同一行，并在菜单每次呈现时刷新代理快照，解决 GitHub `.pkg` 看不到当前线路的问题。
- 主窗口右侧内容区采用更柔和的深灰蓝渐变背景，减少近纯黑空白区域。
- App / Xcode / portable runtime 统一为 v1.2.10 / build 1210。

## v1.2.9

- 修复 GitHub/Xcode `.pkg` 安装版状态栏菜单被固定为 720pt 滚动框的问题。
- 状态栏菜单在内容未超过当前屏幕时全部自然展开；超过屏幕可用高度时才启用纵向滚动。
- 菜单高度上限根据状态栏窗口实际所在屏幕的 `visibleFrame` 动态更新。
- 保留 v1.2.8 窗口重开、状态栏 shell 自动恢复与恢复模式拖动修复。

## v1.2.8

- 以 v1.2.7 为稳定基线，App / Xcode / portable runtime 统一升级为 v1.2.8 / build 128。
- 修复 portable 主窗口关闭后被 AppKit 释放、状态栏再次打开时 JXA 访问失效 `NSWindow` 并异常退出的问题：窗口生命周期改为 `releasedWhenClosed=false`。
- 状态栏重新打开主窗口前重新确认窗口可移动，并保留 22px 原生 `performWindowDragWithEvent:` 拖拽区，修复重新打开后无法拖动。
- 主状态栏 shell 单次异常退出时先自动重启完整模式一次，第二次失败才进入恢复模式，避免瞬时 AppKit/JXA 故障直接降级。
- portable 状态栏初始服务器/代理菜单与状态刷新改为 fail-soft，异常快照不会中断状态栏进程。
- 恢复模式同步加入窗口保活与原生拖拽区，确保极端降级路径下窗口仍可移动。

## v1.2.7

- 以 `source-4` 为功能基线，并恢复已经成功发布的 v1.2.5 fixed5 发布工程配置。
- App / Xcode / portable runtime 统一升级为 v1.2.7 / build 127。
- CI 与 Release 统一走 `scripts/simulate-release.sh`；strict macOS preflight 自愈 manifest 并使用 Xcode SDK-bound Swift semantic typecheck。
- Release 恢复 `SWIFT_ENABLE_BATCH_MODE=NO`、完整 `xcodebuild-release.log`、失败错误回显和 CI diagnostics 上传。
- 恢复 v1.2.4 Xcode 16.4 编译兼容门禁：Optional switch、独立 `ProxySortPicker`、拆分大型 ViewBuilder、`ProxySortOption: Hashable`、具体 history 类型和 macOS 14 `onChange`。
- portable 恢复 `backgroundWG + goBackground()` 生命周期，相关测试在 TempDir 清理前等待后台任务；修复 httptest handler 中 `t.Fatalf` 的 goroutine 隐患。
- 发布模拟覆盖目标竞态重复测试、shuffle、race、vet、Darwin/arm64 交叉编译、portable ZIP/Mach-O/版本校验，并在真实 Apple Silicon macOS 上继续原生 Xcode Release build、架构和 SHA-256 回放。
- 保留 source-4 的状态缓存平滑、HTTP keep-alive、代理菜单增量刷新、线路切换即时后缀更新和完整左右布局。

## v1.2.5

- 状态栏下拉菜单上传/下载网速改为单行显示，代理组区域使用前后分隔线独立成组。
- 修复状态栏重新选择线路/代理组后顶层代理组后缀不刷新的问题：portable 立即更新本地菜单快照与可见 NSMenu 根标题，原生 SwiftUI 立即保留确认选择并重建对应 Menu identity。
- 防止成功切换后紧接着的短暂旧 Controller `now` 响应把界面重新覆盖回旧线路；portable 代理页同步采用同一确认选择策略。
- 主窗口重构为完整左右布局，移除独立视觉标题栏；portable 删除原 36px HTML titlebar，仅保留 22px 不可见拖拽区域，原生继续使用 hidden title bar / full-size content。
- 左侧标题区重排为蓝紫 `M` 图标 + 两行 `Mihomo Core / 管理面板`，并将标题改为与界面一致的系统字体和主文字色（深色界面呈柔和白色）；版本信息置于其下，移除重复标题。
- 左侧栏宽度统一为 256pt/px，标题字体、字重、间距、主文字色和深色背景与 Dashboard 整体风格统一。
- 流畅度优化：原生 SwiftUI 把 1.2 秒实时状态更新隔离到小型子视图，状态轮询去重，代理索引缓存化；代理页首次加载改为无全局 Busy 的后台加载，`/proxies` 与运行模式并发读取。
- 代理切换关键路径缩短：成功 PUT 后立即更新界面并在后台做可取消的短延迟校准；测速完成不再强制追加一次完整代理拉取。相同代理组的旧校准任务使用 token 隔离，避免晚到任务清掉较新的任务引用。
- portable 状态接口改为“同 profile 最近成功快照立即返回 + 后台 TryLock 刷新”，远端状态读取采用 4 秒单次上限；短暂抖动仅保留最多约 4 秒最近成功状态，持续断线会按时转为离线，不会无限显示旧 Running。
- portable HTTP 客户端基于 Go 默认 Transport 克隆，只扩大安全 keep-alive 连接池；TLS 证书验证、系统代理规则、鉴权和 HTTP 安全开关保持不变。所有写操作仍只发送一次，不做自动重试。
- 状态栏代理菜单改为结构感知增量刷新：仅代理组顺序/成员结构变化时重建 NSMenu 根节点；延时/history/当前线路变化只更新必要后缀，异步线路切换失败仍会定向回滚对应组。
- 版本保持 v1.2.5 / build 125。

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
