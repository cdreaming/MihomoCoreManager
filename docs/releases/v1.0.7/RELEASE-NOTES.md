# Mihomo Core Manager v1.0.7

v1.0.7 是针对 **v1.0.6 即时安装版启动闪退** 的稳定性修复版，继续兼容 Mihomo Core 管理面板 v4.0.0，不改变远端 API 语义。

## 启动闪退修复

- v1.0.6 在 JXA/AppKit 启动阶段直接修改 `NSStatusBarButton` 的 cell 多行属性，并设置 attributed title 做基线偏移。部分 macOS 版本下这条桥接路径可能让 `osascript` 提前退出；portable 宿主此前又把菜单栏脚本退出视为整个 App 结束，因此表现为双击后窗口闪现并立即退出。
- v1.0.7 移除这些高风险启动操作，不再修改 `button.cell.wraps`、`usesSingleLineMode`，也不再使用 `NSBaselineOffsetAttributeName`。
- 状态栏渲染被完整异常保护：双行显示如果在某台机器上不可用，会自动回退到安全单行文本，业务主窗口不会因此退出。
- 增加第二层恢复机制：若主 JXA 菜单栏 shell 本身异常退出，Go portable 宿主会自动启动最小恢复 shell，至少保留主窗口和退出菜单，而不是直接闪退。
- 新增运行日志：`~/Library/Application Support/MihomoCoreManager/Runtime/menubar.log`。

## UI 保留

- 状态栏仍以“下载在上 / 上传在下”为正常显示目标，Running / Stopped / Offline 与速度逻辑分离。
- “管理后端”继续位于“设置”下方，保持与侧栏菜单相同字号和行高。
- 后端入口和列表继续不显示重复 M 方块图标。
- 窗口拖动、设置 Tab、Core Secret `⌘V` / 粘贴按钮、多服务器、状态缓存均保留。

版本：App v1.0.7 (build 107)，API 兼容基线 v4.0.0。
