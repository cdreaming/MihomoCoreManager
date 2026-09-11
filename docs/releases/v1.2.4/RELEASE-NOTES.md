# Mihomo Core Manager v1.2.4

v1.2.4 以 v1.2.3 已验证可用的 Mihomo Controller 连接和独立 Controller Secret 为基础，集中增强代理排序、测速和状态栏切换。

## v1.2.4 Hotfix

- **Cloudflare 530 / Error 1033 容错**：GET 请求自动短重试；仍失败时代理页复用最近一次成功的代理/延时快照，状态栏继续使用本地原子快照。错误提示压缩为“Cloudflare Tunnel 暂时断开”，不再展示整段 Cloudflare 返回体。
- **provider 节点修复**：与 MetaCubeXD 一致，并行读取 `/proxies` 和 `/providers/proxies`，将未出现在 `/proxies` 的 provider 叶子节点加入具体线路数据；显示延时前递归解析 `now` 到最终节点，并跳过其它 URL 下的 `delay=0` 占位值。
- **线路延时根因修复**：Mihomo 节点的 URL 专属延时字段是 `extra[url].history`；此前误按 `extra[url]` 直接数组读取，导致代理组可能有延时而具体线路为空。SwiftUI、portable Web UI、Go bridge 和状态栏菜单全部改为读取真实结构。
本次重新打包修复首版 v1.2.4 的代理显示与状态栏性能问题：

- 默认代理组顺序改为读取 `/proxies` 的 `GLOBAL.all`；Mihomo `/group` 由 Go map 构建，不再用于自然顺序。
- 延时显示统一优先级：本次组测速结果 → 对应 Test URL 的 `extra` → 最新 `extra` → legacy `history`。
- Web 代理页在组测速响应返回时立即更新所有同名节点。
- portable 状态栏代理数据由 Go 后台刷新到 `Runtime/proxies.json`，JXA 只读取本地快照；根菜单不执行远端网络请求。
- 代理组子菜单延迟到真正进入该组时构建，减少打开主菜单时的节点创建成本。
- 状态栏测速和线路切换使用异步本地队列，避免 Controller 延迟冻结菜单。
- 代理组菜单项不再添加额外 SF Symbol；线路延时显示恢复。

## 代理页

- 代理组排序：默认 / 延时 / 质量 / 名字。
- 代理列表排序：默认 / 延时 / 质量 / 名字。
- 默认代理组顺序读取 `GET /group`，默认节点顺序保持组内 `all`。
- 质量排序综合存活状态、近期失败、延时抖动、平均延时和最新延时。
- 增加“测速当前组”按钮，仅调用当前组的 `GET /group/{group}/delay`。
- 组测速结果按节点名缓存并共享；同一节点出现在多个组时全部同步显示。
- 测速优先使用组自身 `testUrl` / `expectedStatus`，缺失时使用通用 `generate_204` 测试地址。

## 状态栏

- 每个可见代理组作为状态栏顶层代理组入口。
- 每组子菜单顶部提供“测速此组”。
- Selector / URLTest / Fallback 组可直接选择线路。
- 节点旁显示最新测速/历史延时。
- 切换服务器或重新打开状态栏菜单时刷新代理组内容。

## Controller API

- `GET /group`
- `GET /group/{group}/delay?url=...&timeout=5000`
- `GET /proxies`
- `PUT /proxies/{group}`
- `GET/PATCH /configs`

## 版本

- App: `1.2.4`
- Build: `124`
- Architecture: Apple Silicon `arm64`
- Minimum macOS: `14.0`
