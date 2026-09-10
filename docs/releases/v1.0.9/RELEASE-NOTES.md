# Mihomo Core Manager v1.0.9

v1.0.9 继续兼容 **Mihomo Core 管理面板 v4.0.0**，本次重点修复状态栏组合显示与订阅保存应用在热重载超时时的失败体验。

## 状态栏：图标 + 网速 + 运行状态同时显示

- 新增独立“显示图标”开关，与“显示运行状态”“显示网速”互不排斥。
- 三项可以同时开启；“仅显示图标”仍保留为快捷操作。
- 升级自 v1.0.8 及更早版本时，如果设置文件没有 `showIcon`，自动迁移为显示图标。
- 若三项全部关闭，App 会自动保留图标，避免状态栏项目完全不可见后无法再次打开菜单。
- portable 继续沿用 v1.0.7 的稳定性策略：不修改 `NSStatusBarButton` 的高风险多行 Cell 属性，不使用 CATextLayer/attributedTitle；图标通过系统 SF Symbol 与安全文本标题共存。

## 订阅“保存并应用”热重载超时修复

Mihomo Core 管理面板 v4.0.0 的 `POST /api/subscriptions` 会事务化执行：保存 `subscriptions.conf` → renderer 生成/校验 `config.yaml` → Core 运行时热重载。若热重载 `/configs?force=true` 超时，服务端会回滚新旧配置并返回失败。

v1.0.9 增加客户端兼容回退：

1. 先按 v4.0.0 原语义正常保存并应用；
2. 仅当错误明确同时包含“热重载失败”“timeout/超时”和“已恢复/回滚”时触发回退；
3. 自动停止 Core；
4. 在 Core 停止状态再次调用同一个订阅事务，此时服务端完成保存与 renderer 校验但不执行热重载；
5. 再启动 Core，让新 `config.yaml` 在启动时生效。

URL 校验、renderer、配置语法等其它错误不会触发重启。若停止、再次保存或重新启动任一步失败，客户端会返回清晰的中文错误，并在可行时尽量恢复原运行状态。

## 继续保留

- v1.0.8：“管理后端”下拉与入口等宽。
- v1.0.7：菜单栏异常不拖垮主 App、Recovery Shell、`Runtime/menubar.log`。
- Core Secret `⌘V`/显式粘贴、窗口拖动、设置 Tab、多服务器、集中状态缓存、arm64 Release 工作流。

版本：App v1.0.9 (build 109)，API 兼容基线 v4.0.0。
