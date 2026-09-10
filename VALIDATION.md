# Validation Report — v1.1.9

- App `1.1.9` / Xcode build `119` / portable build `119`。
- v1.1.8 通知、侧栏命中范围、设置/日志首次加载修复保持不变。
- 原生状态栏标签使用图标左置、上传/下载双行、等宽数字与右对齐数值列。
- 原生 `MenuBarExtra` 使用 `.window` 自定义紧凑面板，避免标准 NSMenu 过长和顶部禁用文本层级混乱。
- 原生菜单面板保留服务器选择、Core 全部控制、订阅/日志/升级/MetaCubeXD/设置以及项目检查/升级操作。
- portable JXA 状态栏采用上传在上/下载在下、右对齐与固定宽度，菜单压缩为分组子菜单并使用系统符号。
- Source validator 与 portable Go 回归测试加入 v1.1.9 状态栏门禁。
