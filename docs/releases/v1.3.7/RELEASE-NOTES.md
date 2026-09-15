# MihomoManager v1.3.7

v1.3.7 以 v1.3.6 为基线，参考 Mihomo-Web-Panel v4.1.2 的端口管理实现，为 SwiftUI 与 GoWebUI 两套正式实现补齐 Core 本地端口设置和受管线路端口视图。

## 版本

- App: `1.3.7`
- Build: `1307`
- Architecture: `arm64`
- Minimum macOS: `14.0`

## Core 控制

- Core 控制页重新排版为三行：`服务控制 | 服务信息`、整行 `Core 端口设置`（端口项双列）、`MetaCubeXD | 项目升级`。
- 端口快照与保存复用 Core 服务面板 `/api/ports`、`/api/ports/settings`；配置解析、`mihomo -t` 校验、运行中热重载和失败回滚仍由服务面板负责。
- 优先级说明固定为：
  - 重启/热重载先走 Mihomo Controller API；服务生命周期与日志随后走 Core 服务面板 API；
  - 只有显式配置 SSH 目标时才尝试 mihomo.service；避免因局域网直连失败而自动触发 SSH 认证；

## 线路端口

- “代理切换”之后保留“线路端口”入口；按修订要求移除页面内重复的“Core 端口设置”，仅保留线路映射与逐条测速。
- 线路信息每行显示端口、端口类型、对应线路/代理组、最近延时及“刷新延时”按钮。
- 单行刷新通过 `/api/ports/delay` 执行；Provider 线路与代理组测速语义由 v4.1.2 服务面板统一处理。
- 保持 v4.1.2 的所有权边界：受管 multiport listener 是 reconcile 派生配置，只读展示；标准 Core 端口、Controller/DNS 与非受管 listener 在“Core 端口设置”修改。

## 运行日志

- GoWebUI 日志框 min/max 高度由 `430/560px` 增至 `574/747px`，约增加 1/3；SwiftUI 日志视图同步使用 574pt 最小日志区并允许页面滚动。

## 双实现一致性

- SwiftUI：新增端口数据模型、API Client、AppModel 状态、Core 端口设置和线路端口页面。
- GoWebUI：新增本地认证桥接 `/local/ports*`、Core 卡内编辑器、线路端口页面和逐条测速。
