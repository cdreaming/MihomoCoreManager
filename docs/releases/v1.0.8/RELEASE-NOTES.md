# Mihomo Core Manager v1.0.8

v1.0.8 继续兼容 **Mihomo Core 管理面板 v4.0.0**。本次仅针对侧栏“管理后端”下拉菜单宽度做 UI 收敛，不改变远端 API 或配置语义。

## 管理后端下拉菜单

- portable Dashboard：移除固定 `304px` 下拉宽度，改为继承 `.profile-switcher` 的 `100%` 宽度；弹层与“管理后端”入口左右边界一致，不再侵入右侧主内容区域。
- 原生 SwiftUI：Popover 内容宽度由 304pt 调整为 206pt。侧栏总宽 230pt，导航区域左右各 12pt 内边距，因此 206pt 与“管理后端”按钮实际宽度一致。
- 服务器名称、Endpoint、Secret 警示、选中勾选及“服务器设置…”入口继续保留，并在窄宽度内使用单行省略避免撑宽弹层。

## 稳定性保留

- 保留 v1.0.7 对 v1.0.6 启动闪退的修复。
- 保留菜单栏安全降级、Recovery Shell 与 `Runtime/menubar.log`。
- 保留 Core Secret 粘贴、窗口拖动、设置 Tab、多服务器、集中状态缓存。

版本：App v1.0.8 (build 108)，API 兼容基线 v4.0.0。
