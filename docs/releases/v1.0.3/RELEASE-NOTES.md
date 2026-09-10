# Mihomo Core Manager v1.0.3

这是以 **流畅度和高频状态更新效率** 为核心的优化版本，继续兼容 Mihomo Core 管理面板 v4.0.0。

## 新增

- 主窗口侧边栏新增“设置”Tab。
- 设置页可直接维护服务器、Management URL、Core Secret、Controller URL、`config.yaml` 路径、MetaCubeXD、HTTP/升级选项以及状态栏显示。
- 状态栏上传/下载速度改为上下两行显示。

## 性能优化

- SwiftUI 实时状态独立成 `LiveStatusStore`，高频轮询不再触发所有业务页面刷新。
- 主内容页常驻，切换 Tab 不再重复销毁/创建视图。
- 订阅和日志仅在进入页面时按需加载。
- 流量图改用异步 Canvas。
- Keychain Secret 使用内存缓存。
- Portable runtime 集中轮询远端状态并缓存；Web UI 与菜单栏复用缓存。
- Portable 状态栏定时器不再每次启动 `curl` 子进程。
- Portable UI 移除页面切换动画和高成本模糊，窗口隐藏时暂停页面轮询。

## 保留

- Mihomo Core 管理面板 Dashboard UI。
- 多服务器 / 跨机管理。
- Core Secret `⌘V` 与显式粘贴按钮。
- GitHub Actions arm64 签名、公证、`.pkg` 自动发布机制。

版本：App v1.0.3 (build 103)，API 兼容基线 v4.0.0。
