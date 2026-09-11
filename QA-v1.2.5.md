# QA v1.2.5

## 状态栏下拉菜单

- [ ] 上传/下载实时网速在同一行显示，速率与单位实时更新。
- [ ] 代理组区域上方有分隔线。
- [ ] 最后一个代理组与“Core 控制”之间有分隔线。
- [ ] 代理组懒加载、测速、线路切换不回归。
- [ ] Core 控制、管理与工具、状态栏显示、设置和退出仍可正常使用。

## 主窗口

- [ ] portable 标题栏高度为约 36px，拖拽区域与视觉标题栏一致。
- [ ] 原生 SwiftUI 顶部安全间距约 26pt，红黄绿窗口按钮不与左侧品牌区域重叠。
- [ ] 标题栏颜色与侧栏/主内容整体协调，深色模式无突兀亮灰条带。
- [ ] 窗口仍可通过标题栏正常拖动、缩放、最小化和关闭。

## 回归

- [ ] 状态栏本体仍为上传在上、下载在下的双行实时网速，不受下拉菜单单行改动影响。
- [ ] v1.2.4 Cloudflare 临时断线快照回退、代理排序、延时显示、provider 节点和嵌套组解析均不回归。
- [ ] `python3 scripts/validate-source.py` 通过。
- [ ] `CGO_ENABLED=0 go test ./...` 通过。
- [ ] source manifest 校验通过。

## 发布工程 / v1.2.4 故障回归

- [ ] `ProxySortOption` 保持显式 `Hashable`。
- [ ] 代理排序使用独立 `ProxySortPicker`，不要回退为大型 `ProxiesView` 内联泛型 Picker。
- [ ] 代理组详情保持拆分为 `groupDetailHeader` / `groupDetailToolbar` / `groupMemberList`。
- [ ] `switch proxy?.alive` 使用 `.some(true)` / `.none` / `.some(false)`，不得回退为 `true / nil / false`。
- [ ] 质量排序历史使用显式 `[MihomoProxyDelaySample]` 中间类型。
- [ ] busy cursor 的 `onChange` 使用 macOS 14 双参数 closure。
- [ ] Release 构建保留 `SWIFT_ENABLE_BATCH_MODE=NO`。
- [ ] Release 构建失败时保留并上传 `build/xcodebuild-release.log`，日志末尾必须回显 `error:`。
- [ ] `python3 scripts/release-preflight.py --strict-macos` 在 Apple Silicon `macos-15` Runner 通过。
- [ ] `bash scripts/simulate-release.sh` 在开发/验证环境通过；真正发布仍以 GitHub `macos-15` Xcode 构建为硬门禁。
