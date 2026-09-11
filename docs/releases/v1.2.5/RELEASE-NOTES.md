# Mihomo Core Manager v1.2.5

v1.2.5 以 v1.2.4 为稳定基线，聚焦状态栏下拉菜单分组与主窗口标题栏的紧凑化和视觉统一，不改变 Controller/代理测速数据路径。

## 状态栏下拉菜单

- 上传/下载实时网速从两个纵向菜单项合并为一个单行菜单项：`↑ 上传 …   ↓ 下载 …`。
- 代理组区域保持顶层代理组入口，并在其前后增加分隔线，使代理组独立成组。
- portable 动态代理组始终插入在“代理组”标题与结束分隔线之间，避免与 Core 控制混在同一视觉组。
- 原生 SwiftUI 面板同步使用单行网速卡片，并在代理组前后增加分隔线。

## 主窗口标题栏

- portable 标题栏与拖拽区由 52px 收紧为 36px，约为原高度的 2/3。
- 原生 SwiftUI 顶部安全间距由 38pt 调整为 26pt。
- portable 标题栏背景改用与 Dashboard 一致的中性标题栏变量；深色模式使用 `#1b1e24` 系列背景。
- 原生窗口暴露的 titlebar/chrome backing 使用 Dashboard 深色背景，避免出现默认灰色条带。

## 发布稳定性

- 吸收 v1.2.4 GitHub Actions/Xcode 16.4 发布故障经验：恢复显式 `Optional` switch case、拆分大型 SwiftUI `ViewBuilder`、显式 Picker tag/`Hashable`，并在 Release 构建中关闭 Swift batch mode。
- 新增发布预检与模拟脚本；CI/Release 在真实 Apple Silicon `macos-15` Runner 上校验 Xcode build settings，构建失败时保留并上传完整 Xcode 编译日志。
- 这些改动只强化发布链路，不改变 v1.2.5 Controller/代理数据协议与用户功能。

## 兼容性

- 保留 v1.2.4 的 Cloudflare 530 / Error 1033 容错、代理快照、provider-only 节点合并、嵌套策略组解析、测速与线路切换异步队列。
- 状态栏本体仍保持上传/下载双行速度布局；本次“单行”仅针对状态栏**下拉菜单**。

## 版本

- App: `1.2.5`
- Build: `125`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: `14.0`
